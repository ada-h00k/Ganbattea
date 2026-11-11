use crate::clockwork::{AlarmManager, CountdownTimer, Stopwatch};
use chrono::Local;
use cxx_qt::CxxQtType;
use core::pin::Pin;
use cxx_qt_lib::QString;

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, timer_display, cxx_name = "timerDisplay")]
        #[qproperty(bool, timer_running, cxx_name = "timerRunning")]
        #[qproperty(i64, timer_remaining_ms, cxx_name = "timerRemainingMs")]
        #[qproperty(QString, stopwatch_display, cxx_name = "stopwatchDisplay")]
        #[qproperty(bool, stopwatch_running, cxx_name = "stopwatchRunning")]
        #[qproperty(QString, stopwatch_laps_json, cxx_name = "stopwatchLapsJson")]
        #[qproperty(QString, alarms_json, cxx_name = "alarmsJson")]
        #[qproperty(QString, status_message, cxx_name = "statusMessage")]
        #[qproperty(i32, alarm_event, cxx_name = "alarmEvent")]
        #[qproperty(QString, alarm_event_text, cxx_name = "alarmEventText")]
        type Ganbattea = super::GanbatteaRust;

        #[qinvokable]
        #[cxx_name = "setTimer"]
        fn set_timer(self: Pin<&mut Self>, total_seconds: i32);
        #[qinvokable]
        #[cxx_name = "startTimer"]
        fn start_timer(self: Pin<&mut Self>);
        #[qinvokable]
        #[cxx_name = "pauseTimer"]
        fn pause_timer(self: Pin<&mut Self>);
        #[qinvokable]
        #[cxx_name = "timerTick"]
        fn timer_tick(self: Pin<&mut Self>);

        #[qinvokable]
        #[cxx_name = "startStopwatch"]
        fn start_stopwatch(self: Pin<&mut Self>);
        #[qinvokable]
        #[cxx_name = "pauseStopwatch"]
        fn pause_stopwatch(self: Pin<&mut Self>);
        #[qinvokable]
        #[cxx_name = "resetStopwatch"]
        fn reset_stopwatch(self: Pin<&mut Self>);
        #[qinvokable]
        #[cxx_name = "lapStopwatch"]
        fn lap_stopwatch(self: Pin<&mut Self>);

        #[qinvokable]
        #[cxx_name = "addAlarm"]
        fn add_alarm(self: Pin<&mut Self>, hour: i32, minute: i32, label: &QString);
        #[qinvokable]
        #[cxx_name = "toggleAlarm"]
        fn toggle_alarm(self: Pin<&mut Self>, index: i32, enabled: bool);
        #[qinvokable]
        #[cxx_name = "removeAlarm"]
        fn remove_alarm(self: Pin<&mut Self>, index: i32);
        #[qinvokable]
        #[cxx_name = "checkAlarms"]
        fn check_alarms(self: Pin<&mut Self>);
    }
}

pub struct GanbatteaRust {
    timer_display: QString,
    timer_running: bool,
    timer_remaining_ms: i64,
    stopwatch_display: QString,
    stopwatch_running: bool,
    stopwatch_laps_json: QString,
    alarms_json: QString,
    status_message: QString,
    alarm_event: i32,
    alarm_event_text: QString,
    timer: CountdownTimer,
    stopwatch: Stopwatch,
    stopwatch_laps: Vec<String>,
    alarms: AlarmManager,
}

impl Default for GanbatteaRust {
    fn default() -> Self {
        let alarms = AlarmManager::load();
        let alarms_json = serde_json::to_string(alarms.alarms()).unwrap_or_else(|_| "[]".to_owned());
        Self {
            timer_display: QString::from("00:00:00"),
            timer_running: false,
            timer_remaining_ms: 0,
            stopwatch_display: QString::from("00:00:00.00"),
            stopwatch_running: false,
            stopwatch_laps_json: QString::from("[]"),
            alarms_json: QString::from(alarms_json),
            status_message: QString::from("Bereit für deinen nächsten Fokusmoment."),
            alarm_event: 0,
            alarm_event_text: QString::default(),
            timer: CountdownTimer::default(),
            stopwatch: Stopwatch::default(),
            stopwatch_laps: Vec::new(),
            alarms,
        }
    }
}

impl qobject::Ganbattea {
    pub fn set_timer(mut self: Pin<&mut Self>, total_seconds: i32) {
        if total_seconds <= 0 {
            self.as_mut().set_status_message(QString::from("Bitte eine Dauer größer als 0 Sekunden eingeben."));
            return;
        }
        self.as_mut().rust_mut().timer.set_seconds(total_seconds as u64);
        self.as_mut().refresh_timer();
        self.set_status_message(QString::from("Timer ist eingestellt."));
    }

    pub fn start_timer(mut self: Pin<&mut Self>) {
        let started = self.as_mut().rust_mut().timer.start();
        self.as_mut().refresh_timer();
        if started {
            self.set_status_message(QString::from("Timer läuft. Bleib im Flow."));
        } else {
            self.set_status_message(QString::from("Stelle zuerst eine neue Timer-Dauer ein."));
        }
    }

    pub fn pause_timer(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().timer.pause();
        self.as_mut().refresh_timer();
        self.set_status_message(QString::from("Timer pausiert."));
    }

    pub fn timer_tick(mut self: Pin<&mut Self>) {
        let finished = self.as_mut().rust_mut().timer.tick();
        self.as_mut().refresh_timer();
        self.as_mut().refresh_stopwatch();
        if finished {
            self.as_mut().set_status_message(QString::from("Zeit abgelaufen!"));
            let event = *self.alarm_event() + 1;
            self.as_mut().set_alarm_event(event);
            self.as_mut().set_alarm_event_text(QString::from("Dein Timer ist abgelaufen."));
        }
    }

    pub fn start_stopwatch(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().stopwatch.start();
        self.as_mut().refresh_stopwatch();
        self.set_status_message(QString::from("Stoppuhr läuft."));
    }

    pub fn pause_stopwatch(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().stopwatch.pause();
        self.as_mut().refresh_stopwatch();
        self.set_status_message(QString::from("Stoppuhr pausiert."));
    }

    pub fn reset_stopwatch(mut self: Pin<&mut Self>) {
        let mut rust = self.as_mut().rust_mut();
        rust.stopwatch.reset();
        rust.stopwatch_laps.clear();
        self.as_mut().set_stopwatch_laps_json(QString::from("[]"));
        self.as_mut().refresh_stopwatch();
        self.set_status_message(QString::from("Stoppuhr zurückgesetzt."));
    }

    pub fn lap_stopwatch(mut self: Pin<&mut Self>) {
        let json = {
            let mut rust = self.as_mut().rust_mut();
            let lap = rust.stopwatch.display();
            rust.stopwatch_laps.push(lap);
            serde_json::to_string(&rust.stopwatch_laps).unwrap_or_else(|_| "[]".to_owned())
        };
        self.as_mut().set_stopwatch_laps_json(QString::from(json));
        self.set_status_message(QString::from("Runde gespeichert."));
    }

    pub fn add_alarm(mut self: Pin<&mut Self>, hour: i32, minute: i32, label: &QString) {
        let result = self.as_mut().rust_mut().alarms.add(hour, minute, label.to_string());
        let (json, message) = {
            let rust = self.as_mut().rust_mut();
            (
                serde_json::to_string(rust.alarms.alarms()).unwrap_or_else(|_| "[]".to_owned()),
                result.err(),
            )
        };
        self.as_mut().set_alarms_json(QString::from(json));
        match message {
            Some(error) => self.set_status_message(QString::from(error)),
            None => self.set_status_message(QString::from("Wecker gespeichert.")),
        }
    }

    pub fn toggle_alarm(mut self: Pin<&mut Self>, index: i32, enabled: bool) {
        let result = if index < 0 {
            Err("Ungültiger Wecker-Eintrag.".to_owned())
        } else {
            self.as_mut().rust_mut().alarms.toggle(index as usize, enabled)
        };
        self.as_mut().refresh_alarms();
        match result {
            Ok(()) => self.set_status_message(QString::from("Wecker aktualisiert.")),
            Err(error) => self.set_status_message(QString::from(error)),
        }
    }

    pub fn remove_alarm(mut self: Pin<&mut Self>, index: i32) {
        let result = if index < 0 {
            Err("Ungültiger Wecker-Eintrag.".to_owned())
        } else {
            self.as_mut().rust_mut().alarms.remove(index as usize)
        };
        self.as_mut().refresh_alarms();
        match result {
            Ok(()) => self.set_status_message(QString::from("Wecker gelöscht.")),
            Err(error) => self.set_status_message(QString::from(error)),
        }
    }

    pub fn check_alarms(mut self: Pin<&mut Self>) {
        let due = self.as_mut().rust_mut().alarms.due_now(Local::now());
        if !due.is_empty() {
            let text = due.join(", ");
            let event = *self.alarm_event() + 1;
            self.as_mut().set_alarm_event_text(QString::from(format!("Zeit für: {text}")));
            self.as_mut().set_alarm_event(event);
            self.set_status_message(QString::from("Ein Wecker ist fällig."));
        }
    }

    fn refresh_timer(mut self: Pin<&mut Self>) {
        let (display, running, remaining) = {
            let timer = &self.as_mut().rust_mut().timer;
            (timer.display(), timer.is_running(), timer.remaining_ms())
        };
        self.as_mut().set_timer_display(QString::from(display));
        self.as_mut().set_timer_running(running);
        self.set_timer_remaining_ms(remaining);
    }

    fn refresh_stopwatch(mut self: Pin<&mut Self>) {
        let (display, running) = {
            let stopwatch = &self.as_mut().rust_mut().stopwatch;
            (stopwatch.display(), stopwatch.is_running())
        };
        self.as_mut().set_stopwatch_display(QString::from(display));
        self.set_stopwatch_running(running);
    }

    fn refresh_alarms(mut self: Pin<&mut Self>) {
        let json = {
            let rust = self.as_mut().rust_mut();
            serde_json::to_string(rust.alarms.alarms()).unwrap_or_else(|_| "[]".to_owned())
        };
        self.set_alarms_json(QString::from(json));
    }
}
