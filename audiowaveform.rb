require 'ruby-audio'
require 'json'
require 'mkfifo'

class Sound

    FFMPEG_BINARY = '/usr/local/bin/ffmpeg'
    FFMPEG_CODEC = 'pcm_s16le'
    FFMPEG_FORMAT = 'aiff'  # libsndfile supports more codecs in aiff then in wav
    # remove video, remux stereo to mono, output to stdout
    FFMPEG_OPTIONS = "-y -vn -acodec #{FFMPEG_CODEC} -ac 1 -f #{FFMPEG_FORMAT} pipe:1"

    # FFMPEG COMMAND is written such that the input stream can be appended as a
    # simple command line argument. This allows easy stubbing during testing.
    FFMPEG_COMMAND = "#{FFMPEG_BINARY} #{FFMPEG_OPTIONS} -i"
    FFMPEG_LOGFILE = 'log/ffmpeg.log'

    def initialize source:, zoom: 2048, pixels_per_second: nil
        @zoom = zoom
        @pixels_per_second = pixels_per_second 
        @buffer = nil
        fifo = "/tmp/#{Time.now.to_i}.#{Random.rand 10000}.#{$$}"
        File.mkfifo fifo
        pid = spawn"#{FFMPEG_COMMAND} #{source} >#{fifo}",
            in: '/dev/null', err: [FFMPEG_LOGFILE, 'a']
        Process.detach pid
        @ruby_audio_sound = RubyAudio::Sound.new fifo
        # Po-active clean-up: delete the fifo reference from the filesystem
        # once both processes are connected to it.
        File.delete fifo
    end

    def channels
        @ruby_audio_sound.info.channels
    end

    # This is teh sample rate of the original audio file
    def sample_rate
        @ruby_audio_sound.info.samplerate
    end

    # Number of samples that are consolidated into one data point
    # pixels_per_second setting overrides zoom
    def samples_per_pixel 
        @pixels_per_second ? (sample_rate/@pixels_per_second).ceil : @zoom
    end

    # read the the next segment from the audio file into the buffer
    # the segment size is the number of samples that are consolidated
    # into one data-point according to the pixels_per_second or zoom setting.
    def read
        @buffer = RubyAudio::Buffer.new("short", samples_per_pixel, channels) unless @buffer
        frames = @ruby_audio_sound.read(@buffer)
        if frames <= 0
            @ruby_audio_sound.close
            return nil
        end
        @buffer
    end

    # Generate waveform data 
    # - read the file, fragment by fragment
    # - convert the signal to mone by averging all channels
    # - calculate maximum and minimum value for each fragment
    def waveform
        data = []
        while read
            min = @buffer.min
            max = @buffer.max
            data << ( min/256 + 1 ) << ( max/256 )
        end
        { sample_rate: sample_rate,
          samples_per_pixel: samples_per_pixel,
          bits: 8,
          length: data.length / 2,
          data: data
        }
    end
end 
