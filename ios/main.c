/*
 * Azeroth Survivors: the executable's entry point. Everything else is Rust (crates/survivors-ios),
 * linked in from libsurvivors_ios.a; winit's runner inside it calls UIApplicationMain and never
 * returns.
 */
extern int survivors_main(void);

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    return survivors_main();
}
