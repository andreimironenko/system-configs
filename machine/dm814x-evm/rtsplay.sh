#!/bin/sh

echo "You need to specify the stream as this one for instance:"  
echo "rtsp://192.168.9.1:8554:/tmp/flight.sdp"

gst-launch rtspsrc location=rtsp://192.168.9.1:8554:/tmp/flight.sdp ! rtph264depay ! queue ! h264parse access-unit=true ! queue ! omx_h264dec ! omx_scaler ! queue ! omx_ctrl display-mode=OMX_DC_MODE_1080P_60 ! gstperf print-fps=true print-arm-load=true ! omx_videosink sync=false enable-last-buffer=false


