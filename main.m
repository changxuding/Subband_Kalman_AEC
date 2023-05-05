clc;clear all;

% dir = './test_audio/AecSamples/real_iphone';
% dir = './test_audio/aec_respeaker_6mic//qingyinyue';
dir = './test_audio/AEC_Challenge/double_real/2';

echo_file = [dir, '/0woDOjC0p0KzH5nN0fn1Jw_doubletalk_with_movement_mic.wav'];
far_file = [dir , '/0woDOjC0p0KzH5nN0fn1Jw_doubletalk_with_movement_lpb.wav'];

[echo, fs1] = audioread(echo_file,'native');
[far, fs2] = audioread(far_file, 'native');
echo = double(echo);
far = double(far);
if ~(fs1==fs2)
    error('echo file sample rate must equal far file sample rate');
end

% mode :1->subband kalman;
mode = 1;

if mode==1
    out_file = [dir, '/kalman_nlp_out_update.wav'];
    frame_size = 128;
    out = saf_kalman(echo, far, frame_size);
    audiowrite(out_file, out'/32678, fs1);
end


