# Monolith Generator

Project to help automate the generation of virtual instruments based on the
[monolith](https://www.pianobook.co.uk/monolith/) concept by Christian Henson. 

The project currently supports generation of instruments in [Kontakt](#kontakt), 
[SFZ](#sfz) and [DecentSampler](#decentsampler).

## Getting started

Download the `Source Code` zip file from the [Latest Release](https://github.com/StephenTallamy/monolith/releases).

## Recording

There is a Logic Template to help with the recording and editing of the monolith.
For more details on how to use the Logic Template the section on the
[Pianobook Monolith](https://www.pianobook.co.uk/monolith/) page.

## Building instruments

Once you have recorded and edited your samples, copy your monolith samples wav files
into the `samples` directory under the `instruments` directory.

### Configuration

To configure the automation, edit the config.lua. The following variables can be set:

- `instrument`  The name of your instrument.
- `filepath`    Path(s) to the monolith file(s) - can be a single string or a list 
                for multiple mic signals. Lists are comma seperated and enclosed in
                curly brackets `{}`.
- `prefix`      The prefix to use for each file in various names - can be a single
                string or a list for multple mic signals. Lists are comma seperated 
                and enclosed in curly brackets `{}`. The number of prefixes must 
                match the number of filepaths.
- `flavour`     The type of monolith (`DEFAULT`/`SAME_PEDALS`).
- `bpm`         The Logic recording template is set to 115.2 BPM but if you change to
                a different BPM you can set it with this variable.
- `using_split` If you split your monolith (see below) you can set this to `true` 
                (default is `false`).

### Splitting the monolith

The automation scripts can work directly with full monolith files and this makes it
very easy to quickly test out your samples in an instrument across the different 
platforms.

One drawback to running the full monolith directly in samplers 
(particularly Kontakt) is it can put extra strain on CPU and memory. To handle
this you can automatically split the monolith files into files with only one sample
per file.

To generate the split files, [install lua](https://www.lua.org/start.html) and 
then simply run

```
lua splitter.lua
```

Then within your `config.lua` file set `using_split=true` and build your instruments
as described below.

In general it is recommended to use raw monolith until distribution, and then 
consider splitting the monolith.

### Kontakt

Kontakt instruments can be automatically created using Native Instruments
Creator Tools.

Steps to run the automation:

1. Load Creator Tools (1.3 and above) and Kontakt (6.5 and above)
2. In Kontakt load the Template.nki from the instruments directory (you can create 
   your own template if you prefer - see belowxs)
3. In Creator Tools open the `monolith.ncpr` project
4. Open the kontakt.lua script and hit the run button
5. Click the "Push to Kontakt" arrow to apply the changes to the Kontakt instrument

It's generally a good idea to close Creator Tools once you are finished with the
automation as it can cause Kontakt to hang / go slow.

> NOTE: The automation uses Group 0 as a template for all "notes" groups
> as it is currently not possible to automate the creation of source modulators.
> If you want to tweak the ADHSR or velocity modulator, do this in Group 0 before
> running the automation.
>
> The factory preset of "Piano" is a good starting point for the ADHSR envelope.
> You may wish to tweak this as appropriate.
>
> You may wish to use the modulation shaper option for Velocity to create a table
> that matches the velocity feel you wish for your instrument. A reasonable
> starting place is the Factory Default - Keytrack Tables - AR Table.
>
> Should you wish to edit this after the automation has run then:
>
> 1. In the Expert view, Command / Shift multi-select all the note_without_pedal
>    and note_with_pedal groups
> 2. Right-click and click "Set Edit flag for selected group(s)"
> 3. In the Source section open the Mod option for the Amplifier and make
>    and adjustments as appropriate

#### Creating your own Template.nki

If you would like to create your own Template.nki the following steps can be used

1. In Kontakt click the blank instrument area to create an empty instrument
2. Click the Spanner icon to edit the instrument.
3. Open Group Editor, Mapping Editor, Wave Editor and Script Editor
4. Disable "Edit All Groups"
5. In the Expert view, Command / Shift multi-select all the note_without_pedal and
   note_with_pedal groups
6. In the Voices section increase the maximum number of voices from the default 32
   to a much larger number (more than 200), particularly if you are using multiple
   mic positions.
7. To attach the graphics resources, click the "Instrument Options" button
8. In the "Resource Container" click the folder icon and browse for the
   `Resources.nkr` file that is in the instruments folder
9. Edit any of the Group 0 setting such as envelope, velocity curves, etc

#### KSP Scripts

The generated Kontakt files will automatically add the approriate scripts from
Dave Hilowitz's piano template scripts:

https://github.com/dhilowitz/kontakt-piano-template

The scripts should work out of the box, but you can tweak them as required.

### SFZ

To generate a SFZ file, [install lua](https://www.lua.org/start.html) and then simply run

```
lua sfz.lua
```

### DecentSampler

To generate a DecentSampler dspreset file, [install lua](https://www.lua.org/start.html) and then simply run

```
lua ds.lua
```

## Development

> TIP: You can create a long placeholder WAV file for "DOES_NOT_EXIST.wav" using ffmpeg

```
ffmpeg -f lavfi -i "sine=frequency=1000:sample_rate=48000:duration=5358" -ac 2 -c:a pcm_s24le instruments/samples/DOES_NOT_EXIST.wav
```

In the above `duration=5358` is the length of a DEFAULT monolith (1h29m18s).
Use `duration=2756` for a SAME_PEDALS monolith (0h45m56s).
