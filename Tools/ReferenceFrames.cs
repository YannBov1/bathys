using System.Text.Json;
using Bathys.Core;

var source = Path.GetFullPath(args.Length > 0 ? args[0] : "../bathys/Data/site.json");
var output = Path.GetFullPath(args.Length > 1 ? args[1] : "Tests/reference_frames.json");
var site = Site.Load(source);
var plan = DivePlan.Example(site);
var result = DiveSimulator.Run(site, plan);
int switchIndex = result.Frames.FindIndex(f => f.TankId == "stage");
var times = new[] { 0.0, 180.0, 600.0, 1200.0, result.DurationS * .6, result.DurationS };
var cases = times.Select(t => new { queryTimeS = t, frameIndex = result.FrameIndexAt(t), frame = result.At(t) }).ToArray();
var payload = new {
    source = "Godot 4.7.2 C# reference implementation",
    durationS = result.DurationS,
    frameCount = result.Frames.Count,
    switchIndex,
    beforeSwitch = result.Frames[switchIndex - 1],
    afterSwitch = result.Frames[switchIndex],
    cases,
    legs = result.Legs
};
Directory.CreateDirectory(Path.GetDirectoryName(output)!);
File.WriteAllText(output, JsonSerializer.Serialize(payload, Site.JsonOptions));
Console.WriteLine($"Reference frames: {result.Frames.Count}, duration {result.DurationS:F6} s, switch {switchIndex}");
