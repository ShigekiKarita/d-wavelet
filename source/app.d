import plot : plot2D, plotSignal;


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

    import ggplotd.legend : continuousLegend;
    import ggplotd.ggplotd : Facets, Margins, putIn;


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
}
