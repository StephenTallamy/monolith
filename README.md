# Monolith Generator

Project to help automate the generation of virutal instruments based on the
"monolith" concept by Christian Henson.

Currently includes a Creator Tools project for generation of Kontakt template instruments.

The current approach is based on a "Heatmap" monolith. 

To use this code, run the heatmap.lua with appropriate file settings.

The generated Kontakt files are compatible with Dave Hilowitz's piano template scripts:

https://github.com/dhilowitz/kontakt-piano-template

Apply the two KSP files, adjust the variables for the various groups in the 
"Voice Triggering" script and make sure you use the Resources/ directory contents.

> TIP: You can create a long placeholder WAV file for "DOES_NOT_EXIST.wav" using ffmpeg

```
ffmpeg -f lavfi -i "sine=frequency=1000:sample_rate=48000:duration=5796" -c:a pcm_s24le DOES_NOT_EXIST.wav
```