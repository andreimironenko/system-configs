#!/bin/sh

gst-launch filesrc location=$1 ! qtdemux name=mux mux.video_00 ! queue  ! h264parse output-format=1 ! omx_h264dec ! omx_scaler ! omx_ctrl display-mode=OMX_DC_MODE_1080P_30 ! gstperf print-fps=true print-arm-load=true  !  omx_videosink enable-last-buffer=false mux.audio_00

