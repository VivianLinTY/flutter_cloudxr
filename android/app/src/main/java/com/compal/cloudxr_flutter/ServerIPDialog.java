/*
 * Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package com.compal.cloudxr_flutter;

import android.app.AlertDialog;
import android.os.Handler;
import android.os.Looper;
import android.widget.EditText;
import android.util.Patterns;
import android.widget.*;
import android.view.*;

// Adapted from https://twigstechtips.blogspot.com/2011/10/android-allow-user-to-editinput-text.html
public class ServerIPDialog {
    static AlertDialog dialogInstance = null;

    public static boolean isShowing() {
        if (dialogInstance == null) return false;
        return dialogInstance.isShowing();
    }

    public static void show(HelloArActivity activity, String prevCloudIp, String prevCloudAnchor,
                            String prevWebRtcIp, String prevWebRtcRoom, boolean enableMediaPipe) {
        final HelloArActivity thiz = activity;

        if (isShowing()) {
            return;
        }

        final View startupDialog = activity.getLayoutInflater().inflate(R.layout.startup_dialog, null);
        final EditText cloudServerIp = startupDialog.findViewById(R.id.cloud_server_ip);
        final EditText cloudAnchorId = startupDialog.findViewById(R.id.cloud_anchor_id);
        final EditText webrtcServerIp = startupDialog.findViewById(R.id.webrtc_server_ip);
        final EditText webrtcRoomId = startupDialog.findViewById(R.id.webrtc_room_id);
        final CheckBox hostCloudAnchor = startupDialog.findViewById(R.id.host_cloud_anchor_checkbox);
        final CheckBox enableGesture = startupDialog.findViewById(R.id.mediaPipe_checkbox);

        cloudAnchorId.setText(prevCloudAnchor);
        webrtcRoomId.setText(prevWebRtcRoom);
        enableGesture.setChecked(enableMediaPipe);

        cloudServerIp.setHint("127.0.0.1");
        cloudServerIp.setText(prevCloudIp);

        webrtcServerIp.setHint("127.0.0.1");
        webrtcServerIp.setText(prevWebRtcIp);

        AlertDialog.Builder builder = new AlertDialog.Builder(thiz)
                .setTitle("CloudXR Options")
                .setView(startupDialog)
                .setCancelable(false)
                .setPositiveButton("Go", (dialog, whichButton) -> {
                    String cloudIp = cloudServerIp.getText().toString();
                    String webrtcIp = webrtcServerIp.getText().toString();

                    if (Patterns.IP_ADDRESS.matcher(cloudIp).matches()) {
                        thiz.setParams(cloudIp, cloudAnchorId.getText().toString(),
                                webrtcIp, webrtcRoomId.getText().toString(),
                                hostCloudAnchor.isChecked(), enableGesture.isChecked());
                        Handler handler = new Handler(Looper.getMainLooper());
                        handler.post(thiz::doResume);
                    } else {
                        Toast.makeText(thiz.getApplicationContext(),
                                "Invalid IP address. Try again.", Toast.LENGTH_SHORT).show();
                        ServerIPDialog.show(thiz, prevCloudIp, prevCloudAnchor,
                                prevWebRtcIp, prevWebRtcRoom, enableMediaPipe);
                    }
                })
                .setNegativeButton("Exit", (dialog, whichButton) -> {
                    dialogInstance.dismiss();

                    Handler handler = new Handler(Looper.getMainLooper());
                    handler.post(thiz::finish);
                });
        dialogInstance = builder.create();
        dialogInstance.show();

        LogUtils.v("CXR", "App settings dialog shown.");
    }
}
