# Pre-Smart-Core V4.7 Production Baseline

Exact runnable snapshot made immediately before shared V4.7 promotion.

- HEAD at snapshot: `11f523909629b29bb8f328c2fb3a22990104a214`
- Working tree dirty at snapshot: `True`
- BotDoctrine SHA256: `9f9f4d538d21108806812ff11dc43a6d23064684688ce50a28448e2077e35d05`
- BotDeployDoctrine SHA256: `f352848f47a02b16d4bda27027ea23fe212346ce07880e0bc2afb5bdca44facb`

The frozen Deploy module is retargeted to the frozen Doctrine module so future
A/B experiments do not silently inherit the promoted shipping brain.
