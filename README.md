# Subband_Kalman_AEC
Subband kalman filter for echo cancellation, include residual echo suppression as speex.

## Main Parameters for Tuning
    linear kalman filter
    - tap
    residual echo suppression
    - suppress_gain
    others
    - smooth factor
    - min/max value
    - nosie variance update method

## To be Optimized
- dual filter for better control 
- dtd for different residual echo supression between st and dt
- matrix calculation efficiency of m file

## Problem to be Concerned
- bad performance of high frequency in some cases

## Test Audio 
- record from respeaker 6 mic
- [Aec_samples](https://github.com/ewan-xu/AecSamples)
- [AEC-Challenge](https://github.com/microsoft/AEC-Challenge)
## Reference
- [athena-signal](https://github.com/athena-team/athena-signal)
- [distant_speech_recognition](https://github.com/kkumatani/distant_speech_recognition)
- [speexdsp](https://github.com/xiph/speexdsp)
- Multirate digital signal processing,  Crochiere, R. E. , & Rabiner, L. R.
- Study of the General Kalman Filter for Echo Cancellation, Paleologu C ,  Benesty J ,  Ciochina S
- On Adjusting the Learning Rate in Frequency Domain Echo Cancellation With Double-Talk, Valin J M 