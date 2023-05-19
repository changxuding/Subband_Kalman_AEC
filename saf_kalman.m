function out = saf_kalman(mic, spk, frame_size)

    out_len = min(length(mic),length(spk));
    out = zeros(out_len,1);
    out_num = floor(out_len/frame_size);
    st = init(frame_size);
    
    for i = 1 : out_num
        mic_frame = mic((i - 1) * frame_size + 1 : i * frame_size);
        spk_frame = spk((i - 1) * frame_size + 1 : i * frame_size);
        [st, out_frame] = saf_process(st, mic_frame, spk_frame);
        out(1+(i-1)*frame_size:i*frame_size) = out_frame;
    end
    
    function st = init(frame_size)
        % static para
        st.frame_len = frame_size;
        st.K = frame_size*2;
        st.half_bin = st.K / 2 + 1;
        st.win_len = st.K * 2;
        st.notch_radius = .982;
        st.notch_mem = zeros(2,1);
        st.memX = 0;
        st.memD = 0;
        st.memE = 0;
        st.preemph = .98;
        
        % lp win 
        win_st = load('win_para_update.mat');
        st.win_global = win_st.win;
        % subband para
        st.ana_win_echo = zeros(1, st.win_len);
        st.ana_win_far = zeros(1, st.win_len);
        st.sys_win = zeros(1, st.win_len);
        st.tap = 15;
        st.subband_in = zeros(st.half_bin, st.tap);
        st.subband_adf = zeros(st.half_bin, st.tap);
        
        %kalman para
        st.Ryu = ones(st.half_bin,st.tap,st.tap)*5;
        st.w_cov =  ones(st.half_bin, 1)*0.1;
        st.v_cov = ones(st.half_bin, 1)*0.001;
        st.gain = zeros(st.half_bin,st.tap);
        
        % nlp 
        st.Eh = zeros(st.half_bin,1);
        st.Yh = zeros(st.half_bin,1);
        st.est_ps = zeros(st.half_bin,1);
        st.spec_ave = 0.01;
        st.Pey = 0;
        st.Pyy = 0;
        st.beta0 = 0.016;
        st.beta_max = st.beta0/4;
        st.min_leak = 0.005;
        st.echo_noise_ps = 0;
        st.adapt_cnt=0;
        st.res_old_ps = 0;
        st.suppress_gain = 10;
        st.wiener_gain = zeros(st.half_bin,1);
        st.gain_floor = ones(st.half_bin,1).*0.01;
    end

    function [out,mem] = filter_dc_notch16(in, radius, len, mem)
        out = zeros(size(in));
        den2 = radius*radius + .7*(1-radius)*(1-radius);
        for ii=1:len
            vin = in(ii);
            vout = mem(1) + vin;
            mem(1) = mem(2) + 2*(-vin + radius*vout);
            mem(2) = vin - (den2*vout);
            out(ii) = radius*vout; 
        end
    end

    function [st, out] = saf_process(st, mic_frame, spk_frame)
        N = st.frame_len;
        K = st.K;
        [mic_in, st.notch_mem] = filter_dc_notch16(mic_frame, st.notch_radius, N, st.notch_mem);

        st.ana_win_echo = [st.ana_win_echo(N+1:end), mic_in'];
        ana_win_echo_windowed = st.win_global .* st.ana_win_echo;
        ana_wined_echo = ana_win_echo_windowed(1:K)+ana_win_echo_windowed(K+1:2*K);
        fft_out_echo = fft(ana_wined_echo);

        st.ana_win_far = [st.ana_win_far(N + 1:end), spk_frame'];
        ana_win_far_windowed = st.win_global .* st.ana_win_far;
        ana_wined_far = ana_win_far_windowed(1:K)+ana_win_far_windowed(K+1:2*K);
        fft_out_far = fft(ana_wined_far, K);

        st.subband_in = [fft_out_far(1:st.half_bin)', st.subband_in(:,1:st.tap-1)];
        subband_adf_out = sum(st.subband_adf .* st.subband_in,2);
        subband_adf_err = fft_out_echo(1:st.half_bin)' - subband_adf_out;
        
        % kalman update
        for j = 1:st.half_bin
            %update sigmal v
            st.v_cov(j) = 0.99*st.v_cov(j) + 0.01*(abs(subband_adf_err(j)).^2);
            
            Rmu = squeeze(st.Ryu(j,:,:)) + eye(st.tap).*st.w_cov(j);
            Re = real(st.subband_in(j,:) * Rmu * st.subband_in(j,:)') + st.v_cov(j);
            st.gain(j,:) = (Rmu * st.subband_in(j,:)') ./ (Re+1e-10);
            phi = st.gain(j,:) .* subband_adf_err(j);
            st.subband_adf(j,:) = st.subband_adf(j,:) + phi;
            st.Ryu(j,:,:) = (eye(st.tap) - st.gain(j,:).' * st.subband_in(j,:)) * Rmu;
            
            %update sigmal w
            st.w_cov(j) = 0.99* st.w_cov(j) + 0.01 * (sqrt(abs(phi * phi.'))/st.tap);
        end
        
        % compose subband
        if(1)
            % nlp
            [st,nlpout] = nlpProcess(st,subband_adf_err, subband_adf_out);
            ifft_in = [nlpout', fliplr(conj(nlpout(2:end-1)'))];
        else
            ifft_in = [subband_adf_err', fliplr(conj(subband_adf_err(2:end-1)'))];
        end
        fft_out = ifft(ifft_in);
        win_in = [fft_out, fft_out];
        comp_out = win_in .* st.win_global;
        st.sys_win = st.sys_win + comp_out;
        out = st.sys_win(1 : N); 
        st.sys_win = [st.sys_win(N + 1 : end), zeros(1, N)];
        st.adapt_cnt = st.adapt_cnt + 1;
    end

    function [st,nlp_out] = nlpProcess(st, error, est_echo)
        st.est_ps = abs(est_echo).^2;
        res_ps = abs(error).^2;

        Eh_curr = res_ps - st.Eh;
        Yh_curr = st.est_ps - st.Yh;
        Pey = sum(Eh_curr.*Yh_curr);
        Pyy = sum(Yh_curr.*Yh_curr);
        st.Eh = (1-st.spec_ave)*st.Eh + st.spec_ave*(res_ps);
        st.Yh = (1-st.spec_ave)*st.Yh + st.spec_ave*(st.est_ps);
        Syy = sum(st.est_ps);
        See = sum(res_ps);
        Pyy = sqrt(Pyy);
        Pey = Pey/(Pyy+1e-10);
        tmp32 = st.beta0*Syy/See;
        alpha = min(tmp32, st.beta_max);
        st.Pyy = (1-alpha)*st.Pyy + alpha*Pyy;
        st.Pey = (1-alpha)*st.Pey + alpha*Pey;
        st.Pyy = max(st.Pyy,1);
        st.Pey = max(st.Pey, st.Pyy*st.min_leak);
        st.Pey = min(st.Pey, st.Pyy);
        leak = st.Pey/st.Pyy;
        if(leak>0.5)
            leak=1;
        end
        residual_ps = leak*st.est_ps*st.suppress_gain;
        
        if(st.adapt_cnt==0)
            st.echo_noise_ps = residual_ps;
        else
            st.echo_noise_ps = max(0.85*st.echo_noise_ps, residual_ps);
        end
        st.echo_noise_ps = max(st.echo_noise_ps, 1e-10);
        postser = res_ps./st.echo_noise_ps -1;
        postser = min(postser,100);
        if(st.adapt_cnt==0)
            st.res_old_ps = res_ps;
        end
        prioriser = 0.5.*max(0, postser)+0.5.*(st.res_old_ps./st.echo_noise_ps);
        prioriser = min(prioriser,100);
        st.wiener_gain = prioriser./(prioriser+1);
        st.wiener_gain = max(st.wiener_gain,st.gain_floor);
        st.res_old_ps = 0.8*st.res_old_ps + 0.2*st.wiener_gain.*res_ps;
        nlp_out = st.wiener_gain.*error;
    end
end
