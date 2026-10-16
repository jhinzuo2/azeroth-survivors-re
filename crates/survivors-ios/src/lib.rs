//! Azeroth Survivors on iOS. This crate is the app's entry point and nothing else.
//!
//! The iOS app's `main` calls [`survivors_main`]; from there it is the same client the desktop
//! `warcraft-survivors` launcher runs, through [`benilla_app::run_survivors`].

use benilla_app::BuildId;

/// The iOS entry point. Returns only if the app exits through Bevy; iOS itself ends the process
/// from inside `UIApplicationMain`.
#[no_mangle]
pub extern "C" fn survivors_main() -> i32 {
    let exit = benilla_app::run_survivors(BuildId {
        version: env!("CARGO_PKG_VERSION"),
        describe: env!("BENILLA_GIT_DESCRIBE"),
        sha: env!("BENILLA_GIT_SHA"),
        short: env!("BENILLA_GIT_SHORT"),
        date: env!("BENILLA_GIT_DATE"),
        profile: env!("BENILLA_PROFILE"),
        // The phone has no source folder; game data comes from the app container.
        project_dir: "",
        ..Default::default()
    });
    match exit {
        benilla_app::AppExit::Success => 0,
        benilla_app::AppExit::Error(code) => i32::from(code.get()),
    }
}
