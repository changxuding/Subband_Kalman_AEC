clc;clear all;

dir = './dt/zhoujielun';

echo_file = [dir, '/echo.wav'];
far_file = [dir , '/far.wav'];

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
    out_file = [dir, '/kalman_nlp_out.wav'];
    frame_size = 128;
    out = saf_kalman(echo, far, frame_size);
    audiowrite(out_file, out'/32678, fs1);
end


