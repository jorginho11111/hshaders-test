# probe-post1 — the single-pass post probe

The two-pass post chain ([probe-post](../probes/probe-post)) closes the app.
Inside the app, a chain allocates `Rgba16Float` targets and a history texture;
a single pass draws straight to the screen with none of that machinery.

This probe is the counter-test: ONE post pass, no options, no chain, just a
warm tint. If it survives where probe-post dies, the chain is the trigger.

The [manifest](horizon-shaders.toml) is built as its own pack
(`probe-post1.hshader` in the release assets).
