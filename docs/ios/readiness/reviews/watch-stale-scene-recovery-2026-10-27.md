# Watch capture stale-scene recovery

The 4ce0d2b capture stopped at 15 of 104 images. Its German metronome diagnostic records Carousel repeatedly attempting to terminate the same app PID (22319), waiting more than 100 seconds for its exit context, then trying to activate the stale scene and reporting `Scene update failed. Client process exited.` Boot readiness alone cannot remove that scene from an already booted simulator.

The capture helper now recognizes only the owned Watch bundle's matching PID termination and delayed-exit records together with that client-exit signature, after the existing narrowly recognized scene-update launch error. Before the next already-budgeted attempt it shuts down, boots, and waits for the **same capture-created Watch UDID**. It does not erase a simulator, reset shared CoreSimulator services, touch the paired phone, increase the three-attempt maximum, or retry timeouts and unrelated errors. A second stale-scene failure after recovery terminates capture instead of repeatedly rebooting.

Every original launch failure stays in `launches.json`, alongside recovery state and per-command logs. A recovery command failure is terminal. Successful relaunch still requires fresh token, revision, language and page-state probes before and after the actual screenshot, full pixel decoding and all 104 distinct captures before a manifest exists. Recovery is infrastructure handling, not proof of application correctness or a device lifecycle test pass.

Apple documents simulator lifecycle commands in [Getting the Most Out of Simulator (WWDC 2019)](https://devstreaming-cdn.apple.com/videos/wwdc/2019/418o9bbtoe880sauh/418/418_getting_the_most_out_of_simulator.pdf). This change scopes shutdown to one known UDID, never `all`.

Validation: local tests exercise positive and negative diagnostic classification, exact command order and target, preserved original errors and fresh tokens, terminal restart failures and bounded repeated failure. Native recovery and a complete 104-image result remain unverified until a new GitHub Actions run succeeds; the failed 4ce0d2b run is not reclassified as passed.
