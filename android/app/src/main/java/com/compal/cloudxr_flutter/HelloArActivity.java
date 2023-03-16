/*
 * Copyright 2017 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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

import android.hardware.display.DisplayManager;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.os.Handler;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.Toast;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import android.content.Context;
import android.content.SharedPreferences;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.android.TransparencyMode;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

import androidx.annotation.NonNull;

import com.google.android.material.snackbar.Snackbar;

/**
 * This is a simple example that shows how to create an augmented reality (AR) application using the
 * ARCore C API.
 */
public class HelloArActivity extends FlutterActivity
        implements GLSurfaceView.Renderer, DisplayManager.DisplayListener {
    private static final String TAG = "CXR ArCore";
    private static final int SNACKBAR_UPDATE_INTERVAL_MILLIS = 1000; // In milliseconds.

    private static final String MESSAGES_CHANNEL = "com.compal.cloudxr/messages";
    private static final String EVENTS_CHANNEL = "com.compal.cloudxr/events";

    SharedPreferences prefs = null;
    final String cloudIpAddrPref = "cxr_last_server_ip_addr";
    final String cloudAnchorPref = "cxr_last_cloud_anchor";
    final String webrtcIpAddrPref = "webrtc_last_server_ip_addr";
    final String webrtcRoomIdPref = "webrtc_last_room_id";
    final String enableMediaPipePref = "mediapipe_last_enable";

    private GLSurfaceView surfaceView;
    private String cmdlineFromIntent = "";

    private boolean wasResumed = false;
    private boolean viewportChanged = false;
    private int viewportWidth;
    private int viewportHeight;

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    // Opaque native pointer to the native application instance.
    private long nativeApplication;
    private GestureDetector gestureDetector;

    private Snackbar loadingMessageSnackbar;
    private Handler planeStatusCheckingHandler;
    private final Runnable planeStatusCheckingRunnable =
            new Runnable() {
                @Override
                public void run() {
                    // The runnable is executed on main UI thread.
                    try {
                        if (JniInterface.hasDetectedPlanes(nativeApplication)) {
                            if (loadingMessageSnackbar != null) {
                                loadingMessageSnackbar.dismiss();
                            }
                            loadingMessageSnackbar = null;
                        } else {
                            planeStatusCheckingHandler.postDelayed(
                                    planeStatusCheckingRunnable, SNACKBAR_UPDATE_INTERVAL_MILLIS);
                        }
                    } catch (Exception e) {
                        LogUtils.e(TAG, e.getMessage());
                    }
                }
            };

    @NonNull
    @Override
    public TransparencyMode getTransparencyMode() {
        return TransparencyMode.transparent;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        prefs = getSharedPreferences("cloud_xr_prefs", Context.MODE_PRIVATE);

        FrameLayout layout = findViewById(android.R.id.content);

        for (int i = 0; i < layout.getChildCount(); i++) {
            View view = layout.getChildAt(i);
            if (view instanceof FlutterView) {
                view.setOnTouchListener((v, event) -> {
                    gestureDetector.onTouchEvent(event);
                    return super.onTouchEvent(event);
                });
            }
        }

        surfaceView = new GLSurfaceView(this);
        layout.addView(surfaceView, 0, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        // Set up tap listener.
        gestureDetector =
                new GestureDetector(
                        this,
                        new GestureDetector.SimpleOnGestureListener() {
                            @Override
                            public boolean onSingleTapUp(final MotionEvent e) {
                                surfaceView.queueEvent(
                                        () -> JniInterface.onTouched(nativeApplication, e.getX(), e.getY(), false));
                                runOnUiThread(() -> {
                                    if (null != eventSink) {
                                        eventSink.success("touch");
                                    }
                                });
                                return true;
                            }

                            @Override
                            public void onLongPress(final MotionEvent e) {
                                surfaceView.queueEvent(
                                        () -> JniInterface.onTouched(nativeApplication, e.getX(), e.getY(), true));
                            }

                            @Override
                            public boolean onDown(MotionEvent e) {
                                return true;
                            }
                        });

//        surfaceView.setOnTouchListener(
//                (View v, MotionEvent event) -> gestureDetector.onTouchEvent(event));

        // Set up renderer.
        surfaceView.setPreserveEGLContextOnPause(true);
        surfaceView.setEGLContextClientVersion(3);
        surfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0); // Alpha used for plane blending.
        surfaceView.setRenderer(this);
        surfaceView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
        surfaceView.setWillNotDraw(false);

        // check for any data passed to our activity that we want to handle
        cmdlineFromIntent = getIntent().getStringExtra("args");

        JniInterface.assetManager = getAssets();
        nativeApplication = JniInterface.createNativeApplication(getAssets());

        planeStatusCheckingHandler = new Handler();

//        Button button = new Button(this);
//        FrameLayout.LayoutParams fl = new FrameLayout.LayoutParams(400, 100);
//        fl.gravity = Gravity.CENTER;
//        layout.addView(button, fl);
//        button.setOnClickListener(view -> {
//            UdpClient.getInstance().sendByteCmd(("Pos,3").getBytes(), 1001);
//        });
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        if (null == methodChannel) {
            methodChannel = new MethodChannel(
                    flutterEngine.getDartExecutor().getBinaryMessenger(), MESSAGES_CHANNEL);
        }
        methodChannel.setMethodCallHandler(
                (call, result) -> {
                    // Note: this method is invoked on the main thread.
                    if (call.method.equals("stop_cloudxr")) {
                        result.success("1");
                        findViewById(android.R.id.content).postDelayed(() ->
                                JniInterface.onTouched(nativeApplication, 0, 0, true), 200);
                    } else if (call.method.contains("connect_to_cloudxr")) {
                        result.success("1");
                        String ip = call.method.replaceAll("connect_to_cloudxr", "");
                        LogUtils.d(TAG, "edge ip = " + ip);
                        setParams(ip, "", ip, "", false, false);
                        doResume();
                    } else {
                        result.notImplemented();
                    }
                }
        );
        if (null == eventChannel) {
            eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger()
                    , EVENTS_CHANNEL);
        }
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                eventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });
    }

    @Override
    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);
        methodChannel.setMethodCallHandler(null);
        methodChannel = null;
        eventChannel.setStreamHandler(null);
        eventChannel = null;
    }

    public void setParams(String cloudIp, String cloudAnchorId, String webRtcIp, String webRtcRoomId,
                          boolean hostCloudAnchor, boolean mediaPipe) {
        SharedPreferences.Editor prefedit = prefs.edit();
        prefedit.putString(cloudIpAddrPref, cloudIp);
        prefedit.putString(cloudAnchorPref, cloudAnchorId);
        prefedit.putString(webrtcIpAddrPref, webRtcIp);
        prefedit.putString(webrtcRoomIdPref, webRtcRoomId);
        prefedit.putBoolean(enableMediaPipePref, mediaPipe);
        prefedit.commit();

        JniInterface.setArgs(nativeApplication, "-s " + cloudIp + " -c " +
                (hostCloudAnchor ? "host" : cloudAnchorId));

//        UdpClient.getInstance().connect(cloudIp, 8001);
    }

    public void doResume() {
        JniInterface.onResume(nativeApplication, getApplicationContext(), this);
        surfaceView.onResume();

        loadingMessageSnackbar =
                Snackbar.make(
                        HelloArActivity.this.findViewById(android.R.id.content),
                        "Searching for surfaces...",
                        Snackbar.LENGTH_INDEFINITE);
        // Set the snackbar background to light transparent black color.
        loadingMessageSnackbar.getView().setBackgroundColor(0xbf323232);
        loadingMessageSnackbar.show();
        planeStatusCheckingHandler.postDelayed(
                planeStatusCheckingRunnable, SNACKBAR_UPDATE_INTERVAL_MILLIS);

        // Listen to display changed events to detect 180° rotation, which does not cause a config
        // change or view resize.
        getSystemService(DisplayManager.class).registerDisplayListener(this, null);
        wasResumed = true;
    }

    protected void checkLaunchOptions() {
        if (wasResumed)
            return;

        LogUtils.v(TAG, "Checking launch options..");

        // we're done with permission checks, so can tell native now is safe to
        // try to load files and such.
        JniInterface.handleLaunchOptions(nativeApplication, cmdlineFromIntent);

        // check if the native code already has a server IP, and if so
        // we will skip presenting the IP entry dialog for now...
        String jniIpAddr = JniInterface.getServerIp(nativeApplication);
        if (jniIpAddr.isEmpty()) {
            String prevCloudIP = prefs.getString(cloudIpAddrPref, "");
            String prevCloudAnchor = prefs.getString(cloudAnchorPref, "");
            String prevWebRtcIP = prefs.getString(webrtcIpAddrPref, "");
            String prevWebRtcRoom = prefs.getString(webrtcRoomIdPref, "");
            boolean prevEnableMediaPipe = prefs.getBoolean(enableMediaPipePref, false);
//            ServerIPDialog.show(this, prevCloudIP, prevCloudAnchor,
//                    prevWebRtcIP, prevWebRtcRoom, prevEnableMediaPipe);
        } else {
            doResume();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        // We require camera, internet, and file permissions to function.
        // If we don't yet have permissions, need to go ask the user now.
        if (!PermissionHelper.hasPermissions(this)) {
            PermissionHelper.requestPermissions(this);
            return;
        }

        // if we had permissions, we can move on to checking launch options.
        checkLaunchOptions();
    }

    private void doPause() {
        surfaceView.onPause();
        JniInterface.onPause(nativeApplication);

        planeStatusCheckingHandler.removeCallbacks(planeStatusCheckingRunnable);

        getSystemService(DisplayManager.class).unregisterDisplayListener(this);
    }

    @Override
    public void onPause() {
        LogUtils.v(TAG, "onPause");
        super.onPause();
        if (wasResumed) {
            doPause();
            wasResumed = false;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();

        // Synchronized to avoid racing onDrawFrame.
        synchronized (this) {
            JniInterface.destroyNativeApplication(nativeApplication);
            nativeApplication = 0;
            wasResumed = false;
        }
    }

    @Override
    public void onSurfaceCreated(GL10 gl, EGLConfig config) {
        GLES20.glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        JniInterface.onGlSurfaceCreated(nativeApplication);
    }

    @Override
    public void onSurfaceChanged(GL10 gl, int width, int height) {
        viewportWidth = width;
        viewportHeight = height;
        viewportChanged = true;
    }

    private boolean lastCloudXrStatus = false;

    @Override
    public void onDrawFrame(GL10 gl) {
        // Synchronized to avoid racing onDestroy.
        synchronized (this) {
            if (nativeApplication == 0) {
                return;
            }

            boolean cloudXrStatus = JniInterface.hasCloudXrAnchor(nativeApplication);
            if (lastCloudXrStatus != cloudXrStatus) {
                lastCloudXrStatus = cloudXrStatus;
                runOnUiThread(() -> {
                    if (null != eventSink) {
                        eventSink.success(cloudXrStatus ? "start_cloudxr" : "stop_cloudxr");
                    }
                });
            }

//            Vector<Float> vector = JniInterface.getHeadPose(nativeApplication);
//            if (!vector.isEmpty()) {
//                runOnUiThread(() -> {
//                    if (null != eventSink) {
//                        eventSink.success("Rot," + -vector.get(0) + "," + vector.get(1) + "," + vector.get(2) + "," + vector.get(3));
//                    }
//                });
//            }

            if (viewportChanged) {
                int displayRotation = getWindowManager().getDefaultDisplay().getRotation();
                JniInterface.onDisplayGeometryChanged(
                        nativeApplication, displayRotation, viewportWidth, viewportHeight);
                viewportChanged = false;
            }

            int status = JniInterface.onGlSurfaceDrawFrame(nativeApplication);
            if (status != 0) {
                LogUtils.e(TAG, "Error [" + status + "] reported during frame update. Finishing activity and exiting.");
                // need to shut down.
                runOnUiThread(() -> {
                    Toast.makeText(getApplicationContext(), "CloudXR ARCore Client: Error [" + status + "], see logs for detail.  Exiting.", Toast.LENGTH_LONG).show();
                    finish();
                });
            } else {
                JniInterface.getCameraFrame(nativeApplication);
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode, @NonNull String[] permissions, @NonNull int[] results) {
        if (PermissionHelper.hasRequiredPermissions(this)) {
            // now that we have permissions, we move on to checking launch options and resuming.
            checkLaunchOptions();
        } else {
            Toast.makeText(this, "Camera and internet permissions needed to run this application", Toast.LENGTH_LONG)
                    .show();
            if (!PermissionHelper.shouldShowRequestPermissionRationale(this)) {
                // Permission denied with checking "Do not ask again".
                PermissionHelper.launchPermissionSettings(this);
            }
            finish();
        }
    }

    // DisplayListener methods
    @Override
    public void onDisplayAdded(int displayId) {
    }

    @Override
    public void onDisplayRemoved(int displayId) {
    }

    @Override
    public void onDisplayChanged(int displayId) {
        viewportChanged = true;
    }
}
