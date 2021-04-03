dofile(scriptPath .. filesystem.preferred("/config_examples.lua"))
-- To use one of the samples set config to the name of the sample, e.g.
--   config=DefaultMulti

config={
    instrument="My Instrument",
    prefix="MIC1",
    filepath="samples/DOES_NOT_EXIST.wav",
    --flavour="DEFAULT",
    --using_split=false,
    --bmp=115.2
}