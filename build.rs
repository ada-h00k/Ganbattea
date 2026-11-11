use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("de.ganbattea.app").qml_file("qml/main.qml"),
    )
    .qt_module("Multimedia")
    .qrc_resources(["assets/alarm.wav"])
    .file("src/ganbattea.rs")
    .build();
}
