//! Platform-neutral timing and alarm logic used by the Qt adapter.

use chrono::{DateTime, Local, NaiveDate, Timelike};
use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant};

const MAX_TIMER_SECONDS: u64 = 7 * 24 * 60 * 60;

#[derive(Debug)]
pub struct CountdownTimer {
    total: Duration,
    remaining: Duration,
    started_at: Option<Instant>,
}

impl Default for CountdownTimer {
    fn default() -> Self {
        Self {
            total: Duration::ZERO,
            remaining: Duration::ZERO,
            started_at: None,
        }
    }
}

impl CountdownTimer {
    pub fn set_seconds(&mut self, seconds: u64) {
        let duration = Duration::from_secs(seconds.min(MAX_TIMER_SECONDS));
        self.total = duration;
        self.remaining = duration;
        self.started_at = None;
    }

    pub fn start(&mut self) -> bool {
        if self.is_running() || self.remaining.is_zero() {
            return false;
        }
        self.started_at = Some(Instant::now());
        true
    }

    pub fn pause(&mut self) {
        self.remaining = self.current_remaining();
        self.started_at = None;
    }

    pub fn reset(&mut self) {
        self.remaining = self.total;
        self.started_at = None;
    }

    /// Returns true exactly once when the countdown reaches zero.
    pub fn tick(&mut self) -> bool {
        if self.started_at.is_some() && self.current_remaining().is_zero() {
            self.remaining = Duration::ZERO;
            self.started_at = None;
            return true;
        }
        false
    }

    pub fn is_running(&self) -> bool {
        self.started_at.is_some()
    }

    pub fn remaining_ms(&self) -> i64 {
        self.current_remaining().as_millis().min(i64::MAX as u128) as i64
    }

    pub fn display(&self) -> String {
        format_hms(self.current_remaining())
    }

    fn current_remaining(&self) -> Duration {
        match self.started_at {
            Some(start) => self.remaining.saturating_sub(start.elapsed()),
            None => self.remaining,
        }
    }
}

#[derive(Debug, Default)]
pub struct Stopwatch {
    accumulated: Duration,
    started_at: Option<Instant>,
}

impl Stopwatch {
    pub fn start(&mut self) {
        if self.started_at.is_none() {
            self.started_at = Some(Instant::now());
        }
    }

    pub fn pause(&mut self) {
        if let Some(start) = self.started_at.take() {
            self.accumulated = self.accumulated.saturating_add(start.elapsed());
        }
    }

    pub fn reset(&mut self) {
        self.accumulated = Duration::ZERO;
        self.started_at = None;
    }

    pub fn is_running(&self) -> bool {
        self.started_at.is_some()
    }

    pub fn elapsed(&self) -> Duration {
        match self.started_at {
            Some(start) => self.accumulated.saturating_add(start.elapsed()),
            None => self.accumulated,
        }
    }

    pub fn display(&self) -> String {
        format_stopwatch(self.elapsed())
    }
}

fn format_hms(duration: Duration) -> String {
    let seconds = duration.as_secs();
    let hours = seconds / 3_600;
    let minutes = (seconds % 3_600) / 60;
    let seconds = seconds % 60;
    format!("{hours:02}:{minutes:02}:{seconds:02}")
}

fn format_stopwatch(duration: Duration) -> String {
    let total_ms = duration.as_millis();
    let centiseconds = (total_ms / 10) % 100;
    let seconds = (total_ms / 1_000) % 60;
    let minutes = (total_ms / 60_000) % 60;
    let hours = total_ms / 3_600_000;
    format!("{hours:02}:{minutes:02}:{seconds:02}.{centiseconds:02}")
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Alarm {
    pub id: u64,
    pub hour: u32,
    pub minute: u32,
    pub label: String,
    pub enabled: bool,
    #[serde(skip)]
    last_fired_date: Option<NaiveDate>,
}

#[derive(Debug, Default)]
pub struct AlarmManager {
    alarms: Vec<Alarm>,
    next_id: u64,
}

impl AlarmManager {
    pub fn load() -> Self {
        let alarms = data_file()
            .and_then(|path| fs::read_to_string(path).ok())
            .and_then(|content| serde_json::from_str::<Vec<Alarm>>(&content).ok())
            .unwrap_or_default();
        let next_id = alarms.iter().map(|alarm| alarm.id).max().unwrap_or(0).saturating_add(1);
        Self { alarms, next_id }
    }

    pub fn alarms(&self) -> &[Alarm] {
        &self.alarms
    }

    pub fn label_for_id(&self, id: u64) -> Option<&str> {
        self.alarms
            .iter()
            .find(|alarm| alarm.id == id)
            .map(|alarm| alarm.label.as_str())
    }

    pub fn sync_systemd_timers(&self) -> Result<(), String> {
        #[cfg(target_os = "linux")]
        systemd::sync_all(&self.alarms)?;

        Ok(())
    }

    pub fn add(&mut self, hour: i32, minute: i32, label: String) -> Result<(), String> {
        if !(0..=23).contains(&hour) || !(0..=59).contains(&minute) {
            return Err("Please choose a valid time.".to_owned());
        }

        let label = label.trim();
        let label = if label.is_empty() { "Alarm" } else { label };
        let alarm = Alarm {
            id: self.next_id,
            hour: hour as u32,
            minute: minute as u32,
            label: label.to_owned(),
            enabled: true,
            last_fired_date: None,
        };
        self.next_id = self.next_id.saturating_add(1);
        self.alarms.push(alarm.clone());
        self.save()?;
        sync_systemd_alarm(&alarm).map_err(|error| format!("Alarm was saved, but its systemd timer could not be enabled: {error}"))
    }

    pub fn toggle(&mut self, index: usize, enabled: bool) -> Result<(), String> {
        let alarm = self
            .alarms
            .get_mut(index)
            .ok_or_else(|| "The selected alarm no longer exists.".to_owned())?;
        alarm.enabled = enabled;
        if enabled {
            alarm.last_fired_date = None;
        }
        let alarm = alarm.clone();
        self.save()?;
        sync_systemd_alarm(&alarm).map_err(|error| format!("Alarm settings were saved, but its systemd timer could not be updated: {error}"))
    }

    pub fn remove(&mut self, index: usize) -> Result<(), String> {
        if index >= self.alarms.len() {
            return Err("The selected alarm no longer exists.".to_owned());
        }
        let removed = self.alarms.remove(index);
        self.save()?;
        remove_systemd_alarm(removed.id).map_err(|error| format!("Alarm was deleted, but its systemd timer could not be removed: {error}"))
    }

    pub fn due_now(&mut self, now: DateTime<Local>) -> Vec<String> {
        let today = now.date_naive();
        let hour = now.hour();
        let minute = now.minute();
        let mut due = Vec::new();

        for alarm in &mut self.alarms {
            if alarm.enabled
                && alarm.hour == hour
                && alarm.minute == minute
                && alarm.last_fired_date != Some(today)
            {
                alarm.last_fired_date = Some(today);
                due.push(alarm.label.clone());
            }
        }
        due
    }

    fn save(&self) -> Result<(), String> {
        let Some(path) = data_file() else {
            return Err("No user data directory found; alarms could not be saved.".to_owned());
        };
        let parent = path
            .parent()
            .ok_or_else(|| "Invalid storage path for alarms.".to_owned())?;
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not save alarms: {error}"))?;

        let data = serde_json::to_vec_pretty(&self.alarms)
            .map_err(|error| format!("Could not serialize alarms: {error}"))?;
        let mut temporary = path.clone();
        temporary.set_extension("json.tmp");
        fs::write(&temporary, data)
            .map_err(|error| format!("Could not write alarms: {error}"))?;
        fs::rename(&temporary, &path)
            .map_err(|error| format!("Could not finalize the alarms file: {error}"))?;
        Ok(())
    }
}


pub fn systemd_supported() -> bool {
    cfg!(target_os = "linux")
}

fn sync_systemd_alarm(alarm: &Alarm) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        return systemd::sync_alarm(alarm);
    }

    #[cfg(not(target_os = "linux"))]
    {
        let _ = alarm;
        Ok(())
    }
}

fn remove_systemd_alarm(id: u64) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        return systemd::remove_alarm(id);
    }

    #[cfg(not(target_os = "linux"))]
    {
        let _ = id;
        Ok(())
    }
}

#[cfg(target_os = "linux")]
mod systemd {
    use super::Alarm;
    use std::env;
    use std::fs;
    use std::path::{Path, PathBuf};
    use zbus::blocking::{Connection, Proxy};

    const SERVICE_PREFIX: &str = "ganbattea-alarm-";

    fn unit_directory() -> Result<PathBuf, String> {
        let home = env::var_os("HOME")
            .map(PathBuf::from)
            .ok_or_else(|| "Could not determine the home directory for systemd units.".to_owned())?;
        Ok(home.join(".config").join("systemd").join("user"))
    }

    fn manager_proxy(connection: &Connection) -> Result<Proxy<'_>, String> {
        Proxy::new(
            connection,
            "org.freedesktop.systemd1",
            "/org/freedesktop/systemd1",
            "org.freedesktop.systemd1.Manager",
        )
        .map_err(|error| format!("Could not access the systemd user manager: {error}"))
    }

    fn unit_names(id: u64) -> (String, String) {
        let base = format!("{SERVICE_PREFIX}{id}");
        (format!("{base}.service"), format!("{base}.timer"))
    }

    fn write_unit(directory: &Path, name: &str, contents: &str) -> Result<(), String> {
        let path = directory.join(name);
        let temporary = directory.join(format!(".{name}.{}.tmp", std::process::id()));
        fs::write(&temporary, contents)
            .map_err(|error| format!("Could not write systemd unit {name}: {error}"))?;
        fs::rename(&temporary, &path)
            .map_err(|error| format!("Could not install systemd unit {name}: {error}"))
    }

    fn systemd_quote(value: &str) -> String {
        let escaped = value
            .replace('\\', "\\\\")
            .replace('"', "\\\"")
            .replace('%', "%%")
            .replace('$', "$$");
        format!("\"{escaped}\"")
    }

    fn shell_quote(value: &str) -> String {
        format!("'{}'", value.replace('\'', "'\\''"))
    }

    fn service_contents(id: u64) -> Result<String, String> {
        let launch_command = if env::var_os("FLATPAK_ID").is_some() {
            "/usr/bin/flatpak run de.ganbattea.app".to_owned()
        } else {
            let executable = env::current_exe()
                .map_err(|error| format!("Could not locate the Ganbattea executable: {error}"))?;
            let executable = executable
                .to_str()
                .ok_or_else(|| "The Ganbattea executable path is not valid UTF-8.".to_owned())?;
            shell_quote(executable)
        };

        let script = format!(
            "if /usr/bin/pgrep -u __GANBATTE_UID__ -x ganbattea >/dev/null 2>&1; then exit 0; fi; /usr/bin/systemd-run --user --no-block {launch_command} --alarm-trigger {id}"
        );
        let script = systemd_quote(&script).replace("__GANBATTE_UID__", "%U");

        Ok(format!(
            "[Unit]\nDescription=Launch Ganbattea for alarm {id}\n\n[Service]\nType=oneshot\nExecStart=/bin/sh -c {script}\n"
        ))
    }

    fn timer_contents(alarm: &Alarm, service_name: &str) -> String {
        format!(
            "[Unit]\nDescription=Daily Ganbattea alarm {}\n\n[Timer]\nOnCalendar=*-*-* {:02}:{:02}:00\nAccuracySec=1s\nPersistent=true\nUnit={}\n\n[Install]\nWantedBy=timers.target\n",
            alarm.id, alarm.hour, alarm.minute, service_name
        )
    }

    fn sync_with_proxy(
        proxy: &Proxy<'_>,
        directory: &Path,
        alarm: &Alarm,
    ) -> Result<(), String> {
        let (service_name, timer_name) = unit_names(alarm.id);
        let service_path = directory.join(&service_name);
        let timer_path = directory.join(&timer_name);

        if !alarm.enabled {
            let _ = proxy.call_method("StopUnit", &(timer_name.as_str(), "replace"));
            if timer_path.exists() {
                proxy.call_method(
                    "DisableUnitFiles",
                    &(vec![timer_name.clone()], false),
                )
                .map_err(|error| format!("Could not disable systemd timer {timer_name}: {error}"))?;
            }
            if timer_path.exists() {
                fs::remove_file(&timer_path)
                    .map_err(|error| format!("Could not remove systemd timer {timer_name}: {error}"))?;
            }
            if service_path.exists() {
                fs::remove_file(&service_path)
                    .map_err(|error| format!("Could not remove systemd service {service_name}: {error}"))?;
            }
            proxy.call_method("Reload", &())
                .map_err(|error| format!("Could not reload the systemd user manager: {error}"))?;
            return Ok(());
        }

        write_unit(directory, &service_name, &service_contents(alarm.id)?)?;
        write_unit(directory, &timer_name, &timer_contents(alarm, &service_name))?;

        proxy.call_method("Reload", &())
            .map_err(|error| format!("Could not reload the systemd user manager: {error}"))?;
        proxy.call_method(
            "EnableUnitFiles",
            &(vec![timer_name.clone()], false, true),
        )
        .map_err(|error| format!("Could not enable systemd timer {timer_name}: {error}"))?;
        proxy.call_method("StartUnit", &(timer_name.as_str(), "replace"))
            .map_err(|error| format!("Could not start systemd timer {timer_name}: {error}"))?;

        Ok(())
    }

    pub fn sync_all(alarms: &[Alarm]) -> Result<(), String> {
        let directory = unit_directory()?;
        fs::create_dir_all(&directory)
            .map_err(|error| format!("Could not create the systemd user-unit directory: {error}"))?;

        let connection = Connection::session()
            .map_err(|error| format!("Could not connect to the systemd user manager: {error}"))?;
        let proxy = manager_proxy(&connection)?;

        for alarm in alarms {
            sync_with_proxy(&proxy, &directory, alarm)?;
        }

        Ok(())
    }

    pub fn sync_alarm(alarm: &Alarm) -> Result<(), String> {
        let directory = unit_directory()?;
        fs::create_dir_all(&directory)
            .map_err(|error| format!("Could not create the systemd user-unit directory: {error}"))?;

        let connection = Connection::session()
            .map_err(|error| format!("Could not connect to the systemd user manager: {error}"))?;
        let proxy = manager_proxy(&connection)?;
        sync_with_proxy(&proxy, &directory, alarm)
    }

    pub fn remove_alarm(id: u64) -> Result<(), String> {
        let directory = unit_directory()?;
        let (service_name, timer_name) = unit_names(id);
        let service_path = directory.join(&service_name);
        let timer_path = directory.join(&timer_name);

        if !service_path.exists() && !timer_path.exists() {
            return Ok(());
        }

        let connection = Connection::session()
            .map_err(|error| format!("Could not connect to the systemd user manager: {error}"))?;
        let proxy = manager_proxy(&connection)?;

        let _ = proxy.call_method("StopUnit", &(timer_name.as_str(), "replace"));
        if timer_path.exists() {
            proxy.call_method(
                "DisableUnitFiles",
                &(vec![timer_name.clone()], false),
            )
            .map_err(|error| format!("Could not disable systemd timer {timer_name}: {error}"))?;
            fs::remove_file(&timer_path)
                .map_err(|error| format!("Could not remove systemd timer {timer_name}: {error}"))?;
        }
        if service_path.exists() {
            fs::remove_file(&service_path)
                .map_err(|error| format!("Could not remove systemd service {service_name}: {error}"))?;
        }

        proxy.call_method("Reload", &())
            .map_err(|error| format!("Could not reload the systemd user manager: {error}"))?;
        Ok(())
    }
}

fn data_file() -> Option<PathBuf> {
    #[cfg(target_os = "windows")]
    let base = env::var_os("APPDATA").map(PathBuf::from);

    #[cfg(target_os = "macos")]
    let base = env::var_os("HOME")
        .map(PathBuf::from)
        .map(|home| home.join("Library").join("Application Support"));

    #[cfg(all(unix, not(target_os = "macos")))]
    let base = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(PathBuf::from).map(|home| home.join(".local").join("share")));

    base.map(|directory| directory.join("Ganbattea").join("alarms.json"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timer_counts_down_and_can_pause() {
        let mut timer = CountdownTimer::default();
        timer.set_seconds(90);
        assert_eq!(timer.display(), "00:01:30");
        assert!(timer.start());
        std::thread::sleep(Duration::from_millis(30));
        timer.pause();
        assert!(!timer.is_running());
        assert!(timer.remaining_ms() <= 90_000);
        assert!(timer.remaining_ms() > 0);
    }

    #[test]
    fn stopwatch_can_pause_and_resume() {
        let mut stopwatch = Stopwatch::default();
        stopwatch.start();
        std::thread::sleep(Duration::from_millis(20));
        stopwatch.pause();
        let saved = stopwatch.elapsed();
        std::thread::sleep(Duration::from_millis(10));
        assert_eq!(stopwatch.elapsed(), saved);
        stopwatch.start();
        assert!(stopwatch.is_running());
    }

    #[test]
    fn timer_display_formats_hours() {
        let mut timer = CountdownTimer::default();
        timer.set_seconds(3_661);
        assert_eq!(timer.display(), "01:01:01");
    }
}
