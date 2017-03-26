import std.array : array;
import std.algorithm : map;

import ggplotd.aes : aes;
import ggplotd.axes : xaxisLabel, yaxisLabel;
import ggplotd.ggplotd : GGPlotD, putIn;
import ggplotd.geom : geomPoint, geomRectangle;
import ggplotd.colour : colourGradient;
import ggplotd.colourspace : XYZ;
import ggplotd.legend : continuousLegend;

auto geomPointRect(AES)(AES aesRange)
{
    import std.algorithm : map;
    import ggplotd.aes : aes, Pixel, DefaultValues, merge;
    import ggplotd.range : mergeRange;

    return DefaultValues.mergeRange(aesRange)
        .map!((a) => a.merge(aes!("sizeStore", "width", "height", "fill")
        (a.size, a.width, a.height, a.alpha))).geomRectangle;
}

auto plot2D(T)(T array2d)
{
    import std.algorithm : cartesianProduct;
    import std.range : iota;
    auto xstep = 1;
    auto ystep = 1;
    auto xlen = array2d[0].length;
    auto ylen = array2d.length;
    auto xys = cartesianProduct(xlen.iota, ylen.iota);
    auto gg = xys.map!(xy => aes!("x", "y", "colour", "size", "width",
            "height")(xy[0], xy[1], array2d[$-1-xy[1]][xy[0]], 1.0, xstep, ystep))
        .array.geomPointRect.putIn(GGPlotD());
    gg = colourGradient!XYZ("mediumblue-limegreen-orangered").putIn(gg);
    gg = "time".xaxisLabel.putIn(gg);
    gg = "freq".yaxisLabel.putIn(gg);
    return gg;
}

auto plotSignal(T)(T array)
{
    import std.range : enumerate;
    import ggplotd.geom : geomLine;

    auto gg = GGPlotD();
    gg = enumerate(array).map!(a => aes!("x", "y", "colour", "size")(a[0], a[1], 0, 0.1))
        .array.geomLine.putIn(gg);
    gg = "time".xaxisLabel.putIn(gg);
    gg = "gain".yaxisLabel.putIn(gg);
    return gg;
}

auto haarWavelet(T)(T x)
{
    if (x < 0 || 1 <= x)
        return 0.0;
    else if (0 <= x && x < 0.5)
        return 1.0;
    else
        return -1.0;
}

auto waveletTransform(double[] data, int bin = 10, double sigma = 1.0, double winrate = 1.0)
{
    import std.complex : Complex, expi, abs;
    import std.math : exp, log, PI;

    double sigma2 = 2.0 * (sigma ^^ 2.0);
    double[][] p;
    p.length = bin;
    for (size_t fi = 0; fi < bin; ++fi)
    {
        p[fi].length = data.length;
        const a = data.length / (2.0 ^^ (fi / 4.)); // every 1/3 oct.

        // Gabor wavelet
        const offset = cast(int)((-sigma2 * (a ^^ 2.0) * log(winrate)) ^^ 0.5);
        const gaborlen = offset * 2 + 1;
        auto gabors = new Complex!double[gaborlen];
        for (int i = 0; i < gaborlen; ++i)
        {
            const x = (i - offset) / a;
            const d = exp(-(x ^^ 2.0) / sigma2) / ((PI * sigma2) ^^ 0.5);
            gabors[i] = d * expi(PI * x) / (a ^^ 0.5);
        }

        // transform
        for (size_t i = 0; i < data.length; ++i)
        {
            Complex!double g = 0.0;
            for (size_t j = 0; j < gaborlen; ++j)
            {
                const ij = i + j - gaborlen / 2;
                const d = (ij < 0 || ij >= data.length) ? 0.0 : data[ij];
                g += gabors[j] * d;
            }
            p[fi][i] = g.abs;
        }
    }
    return p;
}

void main(string[] args)
{
    import audio : Wave;
    import std.algorithm : min;
    import std.getopt : getopt, defaultGetoptPrinter;
    import ggplotd.ggplotd : Facets, Margins;

    // http://www.wavsource.com/snds_2017-03-05_7549739125831384/people/women/activity_unproductive.wav
    string input = "speech.wav", output = "wavelet.png";
    int bin = 25;
    size_t start = 0, end = size_t.max;
    double sigma = 1.0, winrate = 1.0;

    auto helpInformation = getopt(
        args,
        "input", &input,
        "output", &output,
        "bin", &bin,
        "sigma", &sigma,
        "start", &start,
        "end", &end,
        "winrate", &winrate
    );

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("d-wavelet.",
        helpInformation.options);
    }

    auto wav = Wave(input);
    auto signal = wav.normalized[start .. min(end, $)];

    Facets fig;
    int totalWidth = 1280;
    int totalHeight = totalWidth / 16 * 9;
    int margin = 64;
    int colorBarWidth = 32;
    int colorBarHeight = totalHeight / 2 - margin * 2;
    auto sg = signal.plotSignal;
    sg.put(Margins(margin, margin + colorBarWidth, margin, margin));
    fig = sg.putIn(fig);

    auto wt = signal.waveletTransform(bin, sigma, winrate).plot2D;
    wt.put(continuousLegend(colorBarHeight, colorBarWidth));
    wt.put(Margins(margin, margin, margin, margin));
    fig = wt.putIn(fig);
    fig.save(output, 1, 2, totalWidth, totalHeight);

/*
    [[1., 2.], [3., 4.]].plot2D.save("test.png");

    // http://www.wavsource.com/snds_2017-03-05_7549739125831384/people/women/appeal_2_humanity.wav
    auto wav1 = Wave64("speech2.wav");
    auto signal1 = wav1.normalized()[start .. min(end, $)];
    signal1.plotSignal.save("signal1.png");
    signal1.waveletTransform(bin, sigma, winrate).plot2D.save("wavelet1.png");
*/
}
