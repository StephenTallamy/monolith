# Monolith Generator

Project to help automate the generation of virutal instruments based on the
"monolith" concept by Christian Henson. The project currently supports generation of 
instruments in [Kontakt](#kontakt), [SFZ](#sfz) and [DecentSampler](#decentsampler).

## Set-up

1. Copy your monolith samples into the `samples` directory under the `instruments` directory
2. Edit the config.lua file and set prefix, filepath, flavour and any other variable 

## Kontakt

Kontakt instruments can be automatically created using Native Instruments Creator Tools.

### Automation

Steps to run the automation:

1. Load Creator Tools and Kontakt
2. In Kontakt click the blank instrument area to create a new instrument
3. In Creator Tools open the `monolith.ncpr` project
4. Open the kontakt.lua script and hit the run button
5. Click the "Push to Kontakt" arrow to apply the changes to the Kontakt instrument

It's generally a good idea to close Creator Tools once you are finished with the automation
as it can cause Kontakt to hang / go slow.

### Additional Steps

After the automation has run you will need to perform the following manual steps 
(hopefully these can be automated at some point)

1. Click the Spanner icon to edit the instrument. 
2. Open Group Editor, Mapping Editor, Wave Editor and Script Editor
3. Disable "Edit All Groups"
4. In the Expert view in the Browser pane shift multi-select all the groups for one mic
5. Right-click and click "Set Edit flag for selected group(s)"
6. In the Source section in the instrument window change the output from "default" to Bus 1
7. Repeat steps 4 to 6 for each of the other mics so Mic 2 routes to Bus 2, etc
8. In the Expert view, Command / Shift multi-select all the note_without_pedal and 
   note_with_pedal groups
9. Right-click and click "Set Edit flag for selected group(s)"
10. In the Source section open the Mod option for the Amplifier
11. Click Add Modulator and choose Envelopes - ADHSR
12. In the Modulation section of the instrument window, select the factory preset of "Piano"
   for the ADHSR envelope. You may wish to tweak this as appropriate.
13. Add a second modulator and choose External Sources - Velocity
14. You may wish to use the modulation shaper option for Velocity to create a table that
    matches the velocity feel you wish for your instrument. A reasonable starting place
    is the Factory Default - Keytrack Tables - AR Table.
15. In the Voices section increase the maximum number of voices from the default 32 to a much
    larger number (more than 200), particularly if you are using multiple mic positions.
16. To attach the graphics resources, click the "Instrument Options" button
17. In the "Resource Container" click the folder icon and browse for the Resources.nkr
    file that is in the instruments folder

### Scripts

The generated Kontakt files will automatically add the approriate scripts from 
Dave Hilowitz's piano template scripts:

https://github.com/dhilowitz/kontakt-piano-template

The scripts should work out of the box, but you can tweak them as required.

## SFZ

To generate a SFZ file, [https://www.lua.org/start.html](install lua) and then simply run

```
lua sfz.lua
```

## DecentSampler

To generate a DecentSampler dspreset file, [https://www.lua.org/start.html](install lua) and then simply run

```
lua ds.lua
```

## Development

> TIP: You can create a long placeholder WAV file for "DOES_NOT_EXIST.wav" using ffmpeg

```
ffmpeg -f lavfi -i "sine=frequency=1000:sample_rate=48000:duration=5796" -c:a pcm_s24le DOES_NOT_EXIST.wav
```