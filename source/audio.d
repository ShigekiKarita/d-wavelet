struct RiffChunk
{
    uint id; // BE
    uint size;
    uint format; // BE
}

struct FormatChunk
{
    uint id; // BE
    uint size;
    ushort audioFormat;
    ushort numChannels;
    uint sampleRate;
    uint byteRate;
    ushort blockAlign;
    ushort bitsPerSample;
}

struct DataChunk
{
    uint id; // BE
    uint size;
}

struct WaveInfo
{
    RiffChunk riff;
    FormatChunk format;
    DataChunk data;
}

auto littleToBigEndian(T)(T val)
{
    import std.bitmanip : nativeToLittleEndian, bigEndianToNative;
    return val.nativeToLittleEndian.bigEndianToNative!T;
}


struct Wave
{
    WaveInfo info;
    ulong[] data;
    double bias = 0.0, scale = 1.0;
    double[] normalized;

    void fixEndian()
    {
        this.info.riff.id = this.info.riff.id.littleToBigEndian;
        this.info.riff.format = this.info.riff.format.littleToBigEndian;
        this.info.format.id = this.info.format.id.littleToBigEndian;
        this.info.data.id = this.info.data.id.littleToBigEndian;
    }

    this(string path)
    {
        import std.array : array;
        import std.algorithm : min, max, map;
        import std.bitmanip : bigEndianToNative;
        import std.range : enumerate;
        import std.stdio : File, fread, writeln;
        import std.format : format;


        scope f = File(path, "rb");

        info = f.rawRead(new WaveInfo[1])[0];
        fixEndian();
        if (info.format.numChannels != 1) {
            throw new Exception(
                "Not implemented: wave.info.format.numChannels(%s) != 1"
                .format(info.format.numChannels));
        }

        const numBytes = info.format.bitsPerSample / 4;
        data = new ulong[info.data.size / numBytes];
        ubyte[ulong.sizeof] bs;
        auto maxVal = ulong.min, minVal = ulong.max;
        foreach (ref d; data)
        {
            bs[$-numBytes .. $] = f.rawRead(new ubyte[numBytes]); // raw[n .. n + numBytes];
            d = bigEndianToNative!ulong(bs);
            minVal = min(d, minVal);
            maxVal = max(d, maxVal);
        }

        bias = data[0];
        scale = max(maxVal - bias, bias - minVal);
        normalized = data.map!(x => (x - bias) / scale).array;
    }
}
