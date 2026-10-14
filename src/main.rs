#![cfg_attr(all(target_os = "windows", not(debug_assertions)), windows_subsystem = "windows")]

use qmetaobject::prelude::*;
use qmetaobject::QObjectBox;
use serde::{Deserialize, Serialize};
use std::{
    f32::consts::TAU,
    fs,
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant},
};

const MAX_SECONDS: i32 = 99 * 60 + 59;
const DEFAULT_COLOR: &str = "#ca9ee6";
const SAMPLE_RATE: u32 = 44_100;
/// The alarm stops on its own after this long if nobody reacts.
const ALARM_TIMEOUT: Duration = Duration::from_secs(5 * 60);

/// One row in the stopwatch lap list (sent to QML as JSON).
#[derive(Serialize)]
struct Lap {
    n: usize,
    split: i32,
    total: i32,
    /// "best", "worst" or "" – used by the UI to highlight fastest/slowest laps.
    kind: &'static str,
}

/// A saved tea timer.
#[derive(Clone, Serialize, Deserialize)]
struct Preset {
    name: String,
    seconds: i32,
    temp: i32,
    color: String,
}

impl Preset {
    fn new(name: &str, seconds: i32, temp: i32, color: &str) -> Self {
        Self {
            name: name.to_string(),
            seconds,
            temp,
            color: color.to_string(),
        }
    }

    fn sanitized(name: String, seconds: i32, temp: i32, color: String) -> Self {
        let name = name.trim();
        Self {
            name: if name.is_empty() { "My Tea".into() } else { name.chars().take(24).collect() },
            seconds: seconds.clamp(1, MAX_SECONDS),
            temp: temp.clamp(40, 100),
            color: if color.starts_with('#') { color } else { DEFAULT_COLOR.into() },
        }
    }
}

/// Everything the QML UI talks to.
///
/// Properties are exposed with their snake_case names, e.g. `backend.remaining_ms`.
#[derive(QObject, Default)]
struct Backend {
    base: qt_base_class!(trait QObject),

    // --- Presets (JSON string, parsed by the UI) ---
    presets_json: qt_property!(QString; NOTIFY presets_changed),
    presets_changed: qt_signal!(),

    // --- Current timer state ---
    remaining_ms: qt_property!(i32; NOTIFY state_changed),
    total_ms: qt_property!(i32; NOTIFY state_changed),
    running: qt_property!(bool; NOTIFY state_changed),
    alarming: qt_property!(bool; NOTIFY state_changed),
    tea_name: qt_property!(QString; NOTIFY state_changed),
    tea_temp: qt_property!(i32; NOTIFY state_changed),
    tea_color: qt_property!(QString; NOTIFY state_changed),
    state_changed: qt_signal!(),
    finished: qt_signal!(),

    // --- Stopwatch state ---
    sw_elapsed_ms: qt_property!(i32; NOTIFY sw_changed),
    sw_running: qt_property!(bool; NOTIFY sw_changed),
    sw_laps_json: qt_property!(QString; NOTIFY sw_changed),
    sw_changed: qt_signal!(),

    // --- Stopwatch control ---
    sw_toggle: qt_method!(fn sw_toggle(&mut self) { self.do_sw_toggle(); }),
    sw_lap: qt_method!(fn sw_lap(&mut self) { self.do_sw_lap(); }),
    sw_reset: qt_method!(fn sw_reset(&mut self) { self.do_sw_reset(); }),
    sw_tick: qt_method!(fn sw_tick(&mut self) { self.do_sw_tick(); }),

    // --- Timer control ---
    start: qt_method!(fn start(&mut self, name: String, seconds: i32, temp: i32, color: String) {
        self.begin(name, seconds, temp, color);
    }),
    pause: qt_method!(fn pause(&mut self) { self.do_pause(); }),
    resume: qt_method!(fn resume(&mut self) { self.do_resume(); }),
    reset: qt_method!(fn reset(&mut self) { self.do_reset(); }),
    restart: qt_method!(fn restart(&mut self) {
        self.do_reset();
        self.do_resume();
    }),
    add_time: qt_method!(fn add_time(&mut self, seconds: i32) { self.do_add_time(seconds); }),
    tick: qt_method!(fn tick(&mut self) { self.do_tick(); }),
    stop_alarm: qt_method!(fn stop_alarm(&mut self) {
        self.clear_alarm();
        self.state_changed();
    }),

    // --- Preset management ---
    add_preset: qt_method!(fn add_preset(&mut self, name: String, seconds: i32, temp: i32, color: String) {
        self.presets.push(Preset::sanitized(name, seconds, temp, color));
        self.commit_presets();
    }),
    update_preset: qt_method!(fn update_preset(&mut self, index: i32, name: String, seconds: i32, temp: i32, color: String) {
        if let Some(p) = self.presets.get_mut(index.max(0) as usize) {
            *p = Preset::sanitized(name, seconds, temp, color);
            self.commit_presets();
        }
    }),
    delete_preset: qt_method!(fn delete_preset(&mut self, index: i32) {
        if index >= 0 && (index as usize) < self.presets.len() {
            self.presets.remove(index as usize);
            self.commit_presets();
        }
    }),

    // --- Private state ---
    presets: Vec<Preset>,
    deadline: Option<Instant>,
    alarm_stop: Option<Arc<AtomicBool>>,
    sw_started: Option<Instant>,
    sw_accum_ms: u64,
    sw_lap_totals: Vec<i32>,
}

impl Backend {
    // ---------- persistence ----------

    fn defaults() -> Vec<Preset> {
        vec![
            Preset::new("Green Tea", 120, 80, "#a6d189"),
            Preset::new("Black Tea", 210, 95, "#e78284"),
            Preset::new("Oolong", 180, 90, "#e5c890"),
            Preset::new("White Tea", 240, 85, "#81c8be"),
            Preset::new("Herbal", 360, 100, "#ca9ee6"),
            Preset::new("Rooibos", 420, 100, "#f4b8e4"),
        ]
    }

    fn config_path() -> Option<PathBuf> {
        dirs::config_dir().map(|d| d.join("ganbattea").join("presets.json"))
    }

    fn load(&mut self) {
        self.presets = Self::config_path()
            .and_then(|p| fs::read_to_string(p).ok())
            .and_then(|s| serde_json::from_str::<Vec<Preset>>(&s).ok())
            .unwrap_or_else(Self::defaults);
        self.refresh_json();
    }

    fn save(&self) {
        if let Some(path) = Self::config_path() {
            if let Some(dir) = path.parent() {
                let _ = fs::create_dir_all(dir);
            }
            if let Ok(json) = serde_json::to_string_pretty(&self.presets) {
                let _ = fs::write(path, json);
            }
        }
    }

    fn refresh_json(&mut self) {
        let json = serde_json::to_string(&self.presets).unwrap_or_else(|_| "[]".into());
        self.presets_json = QString::from(json);
    }

    fn commit_presets(&mut self) {
        self.refresh_json();
        self.save();
        self.presets_changed();
    }

    // ---------- alarm ----------

    fn start_alarm(&mut self) {
        self.clear_alarm();
        let stop = Arc::new(AtomicBool::new(false));
        self.alarm_stop = Some(stop.clone());
        self.alarming = true;
        std::thread::spawn(move || play_alarm(stop));
    }

    /// Silences the alarm sound and clears the `alarming` flag (does not emit signals).
    fn clear_alarm(&mut self) {
        if let Some(stop) = self.alarm_stop.take() {
            stop.store(true, Ordering::Relaxed);
        }
        self.alarming = false;
    }

    // ---------- stopwatch ----------

    fn sw_current_ms(&self) -> i32 {
        let running = self.sw_started.map(|s| s.elapsed().as_millis() as u64).unwrap_or(0);
        (self.sw_accum_ms + running).min(i32::MAX as u64) as i32
    }

    fn do_sw_toggle(&mut self) {
        if self.sw_running {
            self.sw_accum_ms = self.sw_current_ms() as u64;
            self.sw_started = None;
            self.sw_running = false;
        } else {
            self.sw_started = Some(Instant::now());
            self.sw_running = true;
        }
        self.sw_elapsed_ms = self.sw_current_ms();
        self.sw_changed();
    }

    fn do_sw_tick(&mut self) {
        if self.sw_running {
            self.sw_elapsed_ms = self.sw_current_ms();
            self.sw_changed();
        }
    }

    fn do_sw_lap(&mut self) {
        let total = self.sw_current_ms();
        if !self.sw_running || total <= self.sw_lap_totals.last().copied().unwrap_or(0) {
            return;
        }
        self.sw_lap_totals.push(total);
        self.refresh_laps();
        self.sw_elapsed_ms = total;
        self.sw_changed();
    }

    fn do_sw_reset(&mut self) {
        self.sw_started = None;
        self.sw_accum_ms = 0;
        self.sw_running = false;
        self.sw_elapsed_ms = 0;
        self.sw_lap_totals.clear();
        self.refresh_laps();
        self.sw_changed();
    }

    /// Rebuilds the lap JSON (newest lap first) and marks the fastest/slowest split.
    fn refresh_laps(&mut self) {
        let totals = &self.sw_lap_totals;
        let splits: Vec<i32> = totals
            .iter()
            .enumerate()
            .map(|(i, &t)| t - if i == 0 { 0 } else { totals[i - 1] })
            .collect();
        let min = splits.iter().min().copied();
        let max = splits.iter().max().copied();
        let laps: Vec<Lap> = splits
            .iter()
            .enumerate()
            .rev()
            .map(|(i, &split)| Lap {
                n: i + 1,
                split,
                total: totals[i],
                kind: if splits.len() < 2 || min == max {
                    ""
                } else if Some(split) == min {
                    "best"
                } else if Some(split) == max {
                    "worst"
                } else {
                    ""
                },
            })
            .collect();
        let json = serde_json::to_string(&laps).unwrap_or_else(|_| "[]".into());
        self.sw_laps_json = QString::from(json);
    }

    // ---------- timer ----------

    fn begin(&mut self, name: String, seconds: i32, temp: i32, color: String) {
        let seconds = seconds.clamp(1, MAX_SECONDS);
        self.clear_alarm();
        self.tea_name = QString::from(name);
        self.tea_temp = temp;
        self.tea_color = QString::from(color);
        self.total_ms = seconds * 1000;
        self.remaining_ms = self.total_ms;
        self.deadline = None;
        self.running = false;
        self.do_resume();
    }

    fn do_resume(&mut self) {
        if self.total_ms > 0 && self.remaining_ms > 0 && !self.running {
            self.deadline = Some(Instant::now() + Duration::from_millis(self.remaining_ms as u64));
            self.running = true;
            self.state_changed();
        }
    }

    fn do_pause(&mut self) {
        if self.running {
            self.do_tick();
            self.running = false;
            self.deadline = None;
            self.state_changed();
        }
    }

    fn do_reset(&mut self) {
        self.clear_alarm();
        self.running = false;
        self.deadline = None;
        self.remaining_ms = self.total_ms;
        self.state_changed();
    }

    fn do_add_time(&mut self, seconds: i32) {
        if self.total_ms == 0 {
            return;
        }
        let ms = (seconds * 1000).max(0);
        self.remaining_ms += ms;
        self.total_ms += ms;
        self.deadline = self.deadline.map(|d| d + Duration::from_millis(ms as u64));
        self.state_changed();
    }

    fn do_tick(&mut self) {
        let Some(deadline) = self.deadline else { return };
        if !self.running {
            return;
        }
        let left = deadline.saturating_duration_since(Instant::now());
        if left.is_zero() {
            self.remaining_ms = 0;
            self.running = false;
            self.deadline = None;
            self.start_alarm();
            self.state_changed();
            self.finished();
        } else {
            self.remaining_ms = left.as_millis() as i32;
            self.state_changed();
        }
    }
}

/// Appends a soft bell-like tone (fundamental + overtone with exponential decay).
fn push_tone(out: &mut Vec<f32>, freq: f32, secs: f32) {
    let n = (secs * SAMPLE_RATE as f32) as usize;
    for i in 0..n {
        let t = i as f32 / SAMPLE_RATE as f32;
        let attack = (t / 0.005).min(1.0);
        let decay = (-t * 6.0 / secs).exp();
        let wave = (TAU * freq * t).sin() + 0.3 * (TAU * freq * 2.0 * t).sin();
        out.push(wave * attack * decay * 0.3);
    }
}

fn push_silence(out: &mut Vec<f32>, secs: f32) {
    out.extend(std::iter::repeat(0.0).take((secs * SAMPLE_RATE as f32) as usize));
}

/// One cycle of the alarm: a rising three-note chime, twice, then a pause.
fn alarm_samples() -> Vec<f32> {
    let mut out = Vec::new();
    for _ in 0..2 {
        push_tone(&mut out, 880.0, 0.20);
        push_tone(&mut out, 1174.66, 0.20);
        push_tone(&mut out, 1318.51, 0.35);
        push_silence(&mut out, 0.15);
    }
    push_silence(&mut out, 1.0);
    out
}

/// Runs on its own thread; loops the alarm until `stop` is set or the timeout is hit.
/// If no audio device is available this silently does nothing.
fn play_alarm(stop: Arc<AtomicBool>) {
    use rodio::{buffer::SamplesBuffer, OutputStream, Sink};

    let Ok((_stream, handle)) = OutputStream::try_default() else { return };
    let Ok(sink) = Sink::try_new(&handle) else { return };
    let samples = alarm_samples();
    let started = Instant::now();

    while !stop.load(Ordering::Relaxed) && started.elapsed() < ALARM_TIMEOUT {
        sink.append(SamplesBuffer::new(1, SAMPLE_RATE, samples.clone()));
        while !sink.empty() && !stop.load(Ordering::Relaxed) {
            std::thread::sleep(Duration::from_millis(50));
        }
    }
    sink.stop();
}

fn main() {
    // Crisp rendering on HiDPI screens (Qt 5).
    std::env::set_var("QT_AUTO_SCREEN_SCALE_FACTOR", "1");

    let mut backend = Backend::default();
    backend.load();
    let backend = QObjectBox::new(backend);

    let mut engine = QmlEngine::new();
    engine.set_object_property("backend".into(), backend.pinned());
    engine.load_data(include_str!("../qml/main.qml").into());
    engine.exec();
}
