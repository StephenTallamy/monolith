# Monolith Generator

Project to help automate the generation of virutal instruments based on the
"monolith" concept by Christian Henson. The project currently supports generation of 
instruments in Kontakt, SFZ and DecentSampler

## Kontakt

Kontakt instruments can be automatically created using Native Instruments Creator Tools.

### Automation

Steps to run the automation:

1. Load Creator Tools and Kontakt
2. In Kontakt click the blank instrument area to create a new instrument
3. In Creator Tools open the `monolith.ncpr` project
4. Open the kontakt.lua script and hit the run button
5. Click the "Push to Kontakt" arrow to apply the changes to the Kontakt instrument

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

### Scripts

The generated Kontakt files are compatible with Dave Hilowitz's piano template scripts:

https://github.com/dhilowitz/kontakt-piano-template

Depending on whether you have a single mic or multiple mics, pick the appropriate KSP files for
Voice Triggering and UI and apply each into their own Script tab in Kontakt. Then configure as below:

#### Voice Triggering

For a multi-mic standard monolith, the following settings are a good starting point:

```
    {                                      Groups for...   Mic 1           Mic 2           Mic 3      }
    declare %note_without_pedal_groups[3 * $NUM_MICS]  := (0,1,2,          17,18,19,       34,35,36)
    declare %note_with_pedal_groups[3 * $NUM_MICS]     := (3,4,5,          20,21,22,       37,38,39)
    declare %release_trigger_groups[1 * $NUM_MICS]     := (6,              23,             40)
    declare %pedal_down_groups[5 * $NUM_MICS]          := (7,8,9,10,11,    24,25,26,27,28, 41,42,43,44,45)
    declare %pedal_up_groups[5 * $NUM_MICS]            := (12,13,14,15,16, 29,30,31,32,33, 46,47,48,49,50)
```

Also, for many instruments you may wish to set

```
    declare $randomize_round_robins := 0
```

#### UI

For a multi-mic standard monolith, the following settings are a good starting point:

```
    {                                       Groups for Mic 1            Groups for Mic 2               Groups for Mic 3       }
    {                                       vvvvvvvvvvvvvvvv            vvvvvvvvvvvvvvvv               vvvvvvvvvvvvvvvv       }
    declare %note_groups[18]            := (0,1,2,3,4,5,                17,18,19,20,21,22,             34,35,36,37,38,39)
    declare %release_trigger_groups[3]  := (6,                          23,                            40)
    declare %pedal_groups[30]           := (7,8,9,10,11,12,13,14,15,16, 24,25,26,27,28,29,30,31,32,33, 41,42,43,44,45,46,47,48,49,50)
```

## Development

> TIP: You can create a long placeholder WAV file for "DOES_NOT_EXIST.wav" using ffmpeg

```
ffmpeg -f lavfi -i "sine=frequency=1000:sample_rate=48000:duration=5796" -c:a pcm_s24le DOES_NOT_EXIST.wav
```