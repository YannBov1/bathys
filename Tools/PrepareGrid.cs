using System.Text.Json;
using Bathys.Core;

// Build-time only. Uses the reference interpolation and smoothing exactly.
var source = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../../bathys/Data/site.json"));
if (args.Length > 0) source = Path.GetFullPath(args[0]);
var output = Path.GetFullPath(args.Length > 1 ? args[1] : "Data/survey_grid.dat");
var site = Site.Load(source);
var minE = site.Samples.Min(s => s.EastingLv95M);
var maxE = site.Samples.Max(s => s.EastingLv95M);
var minN = site.Samples.Min(s => s.NorthingLv95M);
var maxN = site.Samples.Max(s => s.NorthingLv95M);
var width = (int)Math.Round((maxE - minE) / site.SampleSpacingM) + 1;
var height = (int)Math.Round((maxN - minN) / site.SampleSpacingM) + 1;
var raw = Enumerable.Repeat((ushort)65535, width * height).ToArray();
var display = Enumerable.Repeat((ushort)65535, width * height).ToArray();
ushort Encode(double elevation) => (ushort)Math.Clamp((int)Math.Round((elevation - 400) * 100), 0, 65534);
int Index(SurveySample s) => (int)Math.Round((maxN - s.NorthingLv95M) / site.SampleSpacingM) * width +
    (int)Math.Round((s.EastingLv95M - minE) / site.SampleSpacingM);
foreach (var sample in site.Samples)
{
    var index = Index(sample);
    raw[index] = Encode(sample.ElevationNf02M);
    site.TryTerrainSample(sample.EastingLv95M, sample.NorthingLv95M, out var terrain);
    display[index] = Encode(terrain.ElevationNf02M);
}
foreach (var sample in site.InterpolatedSamples) display[Index(sample)] = Encode(sample.ElevationNf02M);
Directory.CreateDirectory(Path.GetDirectoryName(output)!);
using (var stream = File.Create(output))
using (var writer = new BinaryWriter(stream))
{
    writer.Write(System.Text.Encoding.ASCII.GetBytes("BATHGRID"));
    writer.Write(width); writer.Write(height);
    writer.Write(minE); writer.Write(maxN); writer.Write(site.SampleSpacingM);
    foreach (var value in raw) writer.Write(value);
    foreach (var value in display) writer.Write(value);
}
var info = new {
    width, height, minE, maxN, spacingM = site.SampleSpacingM,
    measuredCount = site.Samples.Count, interpolatedCount = site.InterpolatedSamples.Count,
    interpolatedPatchCount = site.InterpolatedPatchCount,
    displaySmoothedMeasuredCount = site.DisplaySmoothedMeasuredCount,
    elevationEncoding = "uint16 little endian, centimetres above 400 m NF02; 65535 means absent"
};
File.WriteAllText(Path.ChangeExtension(output, ".json"), JsonSerializer.Serialize(info, new JsonSerializerOptions { WriteIndented = true }));
Console.WriteLine(JsonSerializer.Serialize(info));
