--backend:js
--define:karaxDebug
--define:nimExperimentalAsyncjsThen
# --define:debugKaraxDsl

patchFile("stdlib", "dom", "dom.nim")
patchFile("karax", "vdom", "vdom.nim")
