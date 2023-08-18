package com.compal.cloudxr_flutter;

import android.content.SharedPreferences;

public class ArModel {
    private SharedPreferences prefs;

    final String cloudIpAddrPref = "cxr_last_server_ip_addr";
    final String cloudAnchorPref = "cxr_last_cloud_anchor";
    final String webrtcIpAddrPref = "webrtc_last_server_ip_addr";
    final String webrtcRoomIdPref = "webrtc_last_room_id";
    final String enableMediaPipePref = "mediapipe_last_enable";

    public ArModel(SharedPreferences prefs) {
        this.prefs = prefs;
    }

    public void setParams(String cloudIp, String cloudAnchorId, String webRtcIp, String webRtcRoomId,
                          boolean hostCloudAnchor, boolean mediaPipe) {
        SharedPreferences.Editor prefedit = prefs.edit();
        prefedit.putString("cxr_last_server_ip_addr", cloudIp);
        prefedit.putString("cxr_last_cloud_anchor", cloudAnchorId);
        prefedit.putString("webrtc_last_server_ip_addr", webRtcIp);
        prefedit.putString("webrtc_last_room_id", webRtcRoomId);
        prefedit.putBoolean("mediapipe_last_enable", mediaPipe);
        prefedit.apply();
    }

    public String getCloudIpAddr() {
        return prefs.getString(cloudIpAddrPref, "");
    }

    public String getAnchor() {
        return prefs.getString(cloudAnchorPref, "");
    }

    public String getWebRtcIpAddr() {
        return prefs.getString(webrtcIpAddrPref, "");
    }

    public String getRoomId() {
        return prefs.getString(webrtcRoomIdPref, "");
    }

    public boolean getMediaPipeStatus() {
        return prefs.getBoolean(enableMediaPipePref, false);
    }
}