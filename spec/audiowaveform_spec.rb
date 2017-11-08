require_relative '../audiowaveform'

bbc_audiowaveform = JSON.parse(File.open('spec/fixtures/BigBuckBunny.audiowaveform.json').read, symbolize_names: true)

describe 'Sound' do
    context '#new' do
        before :each do
            allow(File).to receive(:mkfifo) { |fifo| @fifo = fifo }
            allow(File).to receive(:delete)
            allow(RubyAudio::Sound).to receive(:new)
            allow_any_instance_of(Sound).to receive(:spawn) { |cmd,arg| @command = arg }.and_return(45)
            @sound = Sound.new source: 'http://domain/bucket/tenant/browse.m4a'
        end
        it 'creates a fifo' do
            expect(File).to have_received :mkfifo
        end
        it 'deletes the fifo' do
            expect(File).to have_received(:delete).with @fifo
        end
        it 'creates a RubyAudio::Sound object' do
            expect(RubyAudio::Sound).to have_received(:new).with @fifo
        end
        context 'call to ffmpeg command' do
            subject { @command }
            it { is_expected.to match(%r{^/(\w+/)+ffmpeg }) }
            it { is_expected.to match(%r{ -i +http://domain/bucket/tenant/browse.m4a\b}) }
            it { is_expected.to match(%r{ -vn }) }
            it { is_expected.to match(%r{ pipe:1\b}) }
            it { is_expected.to match(%r{ -acodec +pcm_s}) }
            it { is_expected.to match(%r{ -ac +1}) }
            it { is_expected.to match(%r{ -f }) }
            it { is_expected.to match(%r{ >#{@fifo}}) }
        end
    end
    context 'with test data' do
        before :each do
            stub_const 'Sound::FFMPEG_COMMAND', 'cat'
            stub_const 'Sound::FFMPEG_LOGFILE', '/dev/null'
            @sound = Sound.new source: 'spec/fixtures/BigBuckBunny.aiff'
        end
        it '#channels is 1' do
            expect(@sound.channels).to eq 1
        end
        it '#sample_rate is 48000' do
            expect(@sound.sample_rate).to eq 48000
        end
        it '#samples_per_pixel defaults to 2048' do
            expect(@sound.samples_per_pixel).to eq 2048
        end
        context '#waveform' do
            let (:waveform) { @sound.waveform }
            [ :bits, :length, :sample_rate, :samples_per_pixel ].each do |method|
                it "[:#{method}] is #{bbc_audiowaveform[method]}" do
                    expect(waveform[method]).to eq bbc_audiowaveform[method]
                end
            end
            context "[:data]" do
                it 'peak data approximately equals bbc/audiowaveform data ' do
                    class Integer
                        def == i
                            (self - i).abs <= 1
                        end
                    end
                    expect(waveform[:data]).to eq bbc_audiowaveform[:data]
                end
            end
        end
    end
end
