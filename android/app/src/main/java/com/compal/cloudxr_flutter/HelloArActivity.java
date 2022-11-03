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

import android.graphics.Bitmap;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.hardware.display.DisplayManager;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Message;
import android.text.TextUtils;
import android.util.Size;
import android.view.Display;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.widget.Button;
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
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import androidx.annotation.NonNull;

import com.compal.utils.HandResultUtils;
import com.compal.utils.WebRtcUtils;
import com.google.android.material.snackbar.Snackbar;

import java.nio.IntBuffer;

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

    private HandlerThread mHandlerThread;
    private Handler mHandler;

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
                ((FlutterView) view).setOnTouchListener((v, event) -> {
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

        mHandlerThread = new HandlerThread("WebRtcThread");
        mHandlerThread.start();
        mHandler = new Handler(mHandlerThread.getLooper()) {
            @Override
            public void handleMessage(@NonNull Message msg) {
                //for WebRTC
                int[] rgbPixels = (int[]) msg.obj;
                int width = msg.arg1;
                int height = msg.arg2;
                if (null != WebRtcUtils.sInstance) {
                    try {
                        if (WebRtcUtils.sInstance.peerConnectionClient != null && rgbPixels.length > 0) {
                            WebRtcUtils.sInstance.peerConnectionClient.doStreaming(
                                    rgbPixels, width, height);
                            if (prefs.getBoolean(enableMediaPipePref, false)) {
                                // Create a bitmap.
                                Bitmap bmp = Bitmap.createBitmap(rgbPixels,
                                        width, height, Bitmap.Config.ARGB_8888);
                                HandResultUtils.getInstance().handleBitmap(HandResultUtils.getInstance().mirrorBitmap(bmp));
                                bmp.recycle();
                            }
                        }
                    } catch (Exception e) {
                        runOnUiThread(() -> {
                            Toast.makeText(HelloArActivity.this, "WebRtc Error. Stop it!", Toast.LENGTH_LONG).show();
                            WebRtcUtils.sInstance.stopCall();
                        });
                    }
                }
            }
        };
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
                        JniInterface.onTouched(nativeApplication, 0, 0, true);
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

        WebRtcUtils.ip = webRtcIp;
        WebRtcUtils.roomId = webRtcRoomId;
        WebRtcUtils.SignalingWsUrl = "ws://" + WebRtcUtils.ip;

        JniInterface.setArgs(nativeApplication, "-s " + cloudIp + " -c " +
                (hostCloudAnchor ? "host" : cloudAnchorId));
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

        if (null == WebRtcUtils.sInstance) {
            WebRtcUtils.createInstance(new Size(viewportWidth, viewportHeight));
        }
        WebRtcUtils.sInstance.startCall(getApplicationContext(),
                prefs.getBoolean(enableMediaPipePref, false));
    }

    protected void checkLaunchOptions() {
        if (wasResumed || ServerIPDialog.isShowing())
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
            ServerIPDialog.show(this, prevCloudIP, prevCloudAnchor,
                    prevWebRtcIP, prevWebRtcRoom, prevEnableMediaPipe);
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

        if (null != WebRtcUtils.sInstance && null != WebRtcUtils.sInstance.peerConnectionClient) {
            WebRtcUtils.sInstance.stopCall();
        }

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
        mHandlerThread.quitSafely();
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
                        eventSink.success(cloudXrStatus ?
                                "start_cloudxr" : "stop_cloudxr");
                    }
                });
            }

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
//                getCurrentFrame();
                getCameraFrame();
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

    /**
     * Call from the GLThread to save a picture of the current frame.
     */
    private void getCurrentFrame() {
        int[] pixelData = new int[viewportWidth * viewportHeight];

        // Read the pixels from the current GL frame.
        IntBuffer buf = IntBuffer.wrap(pixelData);
        buf.position(0);
        GLES20.glReadPixels(0, 0, viewportWidth, viewportHeight,
                GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buf);

        // Convert the pixel data from RGBA to what Android wants, ARGB.
        int[] bitmapData = new int[pixelData.length];
        for (int i = 0; i < viewportHeight; i++) {
            for (int j = 0; j < viewportWidth; j++) {
                int p = pixelData[i * viewportWidth + j];
                int b = (p & 0x00ff0000) >> 16;
                int r = (p & 0x000000ff) << 16;
                int ga = p & 0xff00ff00;
                bitmapData[(viewportHeight - i - 1) * viewportWidth + j] = ga | r | b;
            }
        }
        transferRgbToWebRtc(bitmapData, viewportWidth, viewportHeight);
    }

    int fromByteArray(byte[] bytes) {
        return ((bytes[0] & 0xFF) << 24) |
                ((bytes[1] & 0xFF) << 16) |
                ((bytes[2] & 0xFF) << 8) |
                ((bytes[3] & 0xFF) << 0);
    }

    private void getCameraFrame() {
        byte[] yuv = JniInterface.getCameraFrame(nativeApplication);
        if (yuv.length > 0) {
            byte[] vLengthB = new byte[4];
            System.arraycopy(yuv, yuv.length - 4, vLengthB, 0, 4);
            int vLength = fromByteArray(vLengthB);
            byte[] uLengthB = new byte[4];
            System.arraycopy(yuv, yuv.length - 8, uLengthB, 0, 4);
            int uLength = fromByteArray(uLengthB);
            byte[] yLengthB = new byte[4];
            System.arraycopy(yuv, yuv.length - 12, yLengthB, 0, 4);
            int yLength = fromByteArray(yLengthB);
            byte[] uvPixelStrideB = new byte[4];
            System.arraycopy(yuv, yuv.length - 16, uvPixelStrideB, 0, 4);
            int uvPixelStride = fromByteArray(uvPixelStrideB);
            byte[] uvStrideB = new byte[4];
            System.arraycopy(yuv, yuv.length - 20, uvStrideB, 0, 4);
            int uvStride = fromByteArray(uvStrideB);
            byte[] yStrideB = new byte[4];
            System.arraycopy(yuv, yuv.length - 24, yStrideB, 0, 4);
            int yStride = fromByteArray(yStrideB);
            byte[] heightB = new byte[4];
            System.arraycopy(yuv, yuv.length - 28, heightB, 0, 4);
            int height = fromByteArray(heightB);
            byte[] widthB = new byte[4];
            System.arraycopy(yuv, yuv.length - 32, widthB, 0, 4);
            int width = fromByteArray(widthB);

            byte[] yData = new byte[yLength];
            System.arraycopy(yuv, 0, yData, 0, yLength);

            byte[] uData = new byte[uLength];
            System.arraycopy(yuv, yLength, uData, 0, uLength);

            byte[] vData = new byte[vLength];
            System.arraycopy(yuv, yLength + uLength, vData, 0, vLength);

            int[] rgbPixels = new int[width * height];
            ImageUtils.convertYUV420ToARGB8888(yData, uData, vData,
                    width, height, yStride, uvStride, uvPixelStride, rgbPixels);
            transferRgbToWebRtc(rgbPixels, width, height);
        }
    }

    private void transferRgbToWebRtc(int[] rgbPixels, int width, int height) {
        if (null == rgbPixels) {
            return;
        }
        //for WebRTC
        if (null != mHandler) {
            Message message = new Message();
            message.obj = rgbPixels;
            message.arg1 = width;
            message.arg2 = height;
            mHandler.sendMessage(message);
        }
    }

    private Size chooseSupportedSize() {
        Display display = getWindowManager().getDefaultDisplay();
        android.graphics.Point displaySize = new android.graphics.Point();
        display.getSize(displaySize);
        Size targetSize = new Size(displaySize.x, displaySize.y);
        CameraManager cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
        try {
            for (String id : cameraManager.getCameraIdList()) {
                CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(id);
                int facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (facing == CameraCharacteristics.LENS_FACING_BACK) {
                    StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                    Size[] outputSizes = map.getOutputSizes(SurfaceTexture.class);
                    Size optimalSize = null;
                    double targetRatio = (double) targetSize.getWidth() / (double) targetSize.getHeight();
                    LogUtils.d(TAG, String.format("Camera target size ratio: %f width: %d", targetRatio, targetSize.getWidth()));
                    double minCost = 1.7976931348623157E308D;
                    int var10 = outputSizes.length;

                    for (int var11 = 0; var11 < var10; ++var11) {
                        Size size = outputSizes[var11];
                        double aspectRatio = (double) size.getWidth() / (double) size.getHeight();
                        double ratioDiff = Math.abs(aspectRatio - targetRatio);
                        double cost = (ratioDiff > 0.25D ? 10000.0D + ratioDiff * (double) targetSize.getHeight() : 0.0D) + (double) Math.abs(size.getWidth() - targetSize.getWidth());
                        LogUtils.d(TAG, String.format("Camera size candidate width: %d height: %d ratio: %f cost: %f", size.getWidth(), size.getHeight(), aspectRatio, cost));
                        if (cost < minCost) {
                            optimalSize = size;
                            minCost = cost;
                        }
                    }

                    if (optimalSize != null) {
                        LogUtils.d(TAG, String.format("Optimal camera size width: %d height: %d", optimalSize.getWidth(), optimalSize.getHeight()));
                    }
                    return optimalSize;
                }
            }
        } catch (Exception ignore) {
        }
        return new Size(320, 240);
    }
}
