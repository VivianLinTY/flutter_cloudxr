package com.compal.cloudxr_flutter;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.hardware.display.DisplayManager;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.os.Handler;
import android.view.GestureDetector;
import android.view.MotionEvent;
import android.widget.Toast;

import androidx.annotation.NonNull;

import com.google.android.material.snackbar.Snackbar;

import java.lang.ref.WeakReference;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class ArController implements GLSurfaceView.Renderer, DisplayManager.DisplayListener {

    private static final String TAG = "CXR ArCore >> ArController";

    private ArModel model;
    private WeakReference<Activity> view;
    private GLSurfaceView surfaceView;

    private static final int SNACKBAR_UPDATE_INTERVAL_MILLIS = 1000; // In milliseconds.

    private static final String MESSAGES_CHANNEL = "com.compal.cloudxr/messages";
    private static final String EVENTS_CHANNEL = "com.compal.cloudxr/events";

    private String cmdlineFromIntent = "";

    private boolean wasResumed = false;
    private boolean viewportChanged = false;
    private boolean lastCloudXrStatus = false;
    private int viewportWidth;
    private int viewportHeight;

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    // Opaque native pointer to the native application instance.
    private long nativeApplication;

    private Snackbar loadingMessageSnackbar;
    private Handler planeStatusCheckingHandler;

    public ArController(ArModel model, Activity view) {
        this.model = model;
        this.view = new WeakReference<>(view);
    }

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

    public void onCreate() {
        surfaceView = new GLSurfaceView(view.get());
        // Set up renderer.
        surfaceView.setPreserveEGLContextOnPause(true);
        surfaceView.setEGLContextClientVersion(3);
        surfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0); // Alpha used for plane blending.
        surfaceView.setRenderer(this);
        surfaceView.setRenderMode(GLSurfaceView.RENDERMODE_CONTINUOUSLY);
        surfaceView.setWillNotDraw(false);

        // check for any data passed to our activity that we want to handle
        cmdlineFromIntent = view.get().getIntent().getStringExtra("args");

        JniInterface.assetManager = view.get().getAssets();
        nativeApplication = JniInterface.createNativeApplication(view.get().getAssets());
        planeStatusCheckingHandler = new Handler();
    }

    public void onResume() {
        // We require camera, internet, and file permissions to function.
        // If we don't yet have permissions, need to go ask the user now.
        if (!PermissionHelper.hasPermissions(view.get())) {
            PermissionHelper.requestPermissions(view.get());
            return;
        }

        // if we had permissions, we can move on to checking launch options.
        checkLaunchOptions();
    }

    public void onPause() {
        LogUtils.v(TAG, "onPause");
        if (wasResumed) {
            doPause();
            wasResumed = false;
        }
    }

    public void onDestroy() {
        // Synchronized to avoid racing onDrawFrame.
        synchronized (this) {
            JniInterface.destroyNativeApplication(nativeApplication);
            nativeApplication = 0;
            wasResumed = false;
        }
    }

    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        if (null == methodChannel) {
            methodChannel = new MethodChannel(
                    flutterEngine.getDartExecutor().getBinaryMessenger(), MESSAGES_CHANNEL);
        }
        methodChannel.setMethodCallHandler(
                (call, result) -> {
                    // Note: this method is invoked on the main thread.
                    if (call.method.equals("stop_cloudxr")) {
                        result.success("1");
                        surfaceView.postDelayed(() ->
                                JniInterface.onTouched(nativeApplication, 0, 0, true), 200);
                    } else if (call.method.equals("disconnect_to_cloudxr")) {
                        result.success("1");
                        surfaceView.onPause();
                        JniInterface.onPause(nativeApplication);
                    } else if (call.method.contains("connect_to_cloudxr")) {
                        result.success("1");
                        String ip = call.method.replaceAll("connect_to_cloudxr", "");
                        LogUtils.d(TAG, "edge ip = " + ip);
                        model.setParams(ip, "", ip, "", false, false);
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

    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        methodChannel.setMethodCallHandler(null);
        methodChannel = null;
        eventChannel.setStreamHandler(null);
        eventChannel = null;
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
                view.get().runOnUiThread(() -> {
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
                int displayRotation = view.get().getWindowManager().getDefaultDisplay().getRotation();
                JniInterface.onDisplayGeometryChanged(
                        nativeApplication, displayRotation, viewportWidth, viewportHeight);
                viewportChanged = false;
            }

            int status = JniInterface.onGlSurfaceDrawFrame(nativeApplication);
            if (status != 0) {
                LogUtils.e(TAG, "Error [" + status + "] reported during frame update. Finishing activity and exiting.");
                // need to shut down.
                view.get().runOnUiThread(() -> {
                    Toast.makeText(view.get().getApplicationContext(), "CloudXR ARCore Client: Error [" + status + "], see logs for detail.  Exiting.", Toast.LENGTH_LONG).show();
                    triggerRebirth();
                });
            } else {
                JniInterface.getCameraFrame(nativeApplication);
            }
        }
    }

    public void doResume() {
        JniInterface.onResume(nativeApplication, view.get().getApplicationContext(), view.get());
        surfaceView.onResume();

        loadingMessageSnackbar =
                Snackbar.make(view.get().findViewById(android.R.id.content),
                        "Searching for surfaces...",
                        Snackbar.LENGTH_INDEFINITE);
        // Set the snackbar background to light transparent black color.
        loadingMessageSnackbar.getView().setBackgroundColor(0xbf323232);
        loadingMessageSnackbar.show();
        planeStatusCheckingHandler.postDelayed(
                planeStatusCheckingRunnable, SNACKBAR_UPDATE_INTERVAL_MILLIS);

        // Listen to display changed events to detect 180° rotation, which does not cause a config
        // change or view resize.
        view.get().getSystemService(DisplayManager.class).registerDisplayListener(this, null);
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
            String prevCloudIP = model.getCloudIpAddr();
            String prevCloudAnchor = model.getAnchor();
            String prevWebRtcIP = model.getWebRtcIpAddr();
            String prevWebRtcRoom = model.getRoomId();
            boolean prevEnableMediaPipe = model.getMediaPipeStatus();
//            ServerIPDialog.show(this, prevCloudIP, prevCloudAnchor,
//                    prevWebRtcIP, prevWebRtcRoom, prevEnableMediaPipe);
        } else {
            doResume();
        }
    }

    private void doPause() {
        surfaceView.onPause();
        JniInterface.onPause(nativeApplication);

        planeStatusCheckingHandler.removeCallbacks(planeStatusCheckingRunnable);

        view.get().getSystemService(DisplayManager.class).unregisterDisplayListener(this);
    }

    public void triggerRebirth() {
        PackageManager packageManager = view.get().getPackageManager();
        Intent intent = packageManager.getLaunchIntentForPackage(view.get().getPackageName());
        ComponentName componentName = intent.getComponent();
        Intent mainIntent = Intent.makeRestartActivityTask(componentName);
        view.get().startActivity(mainIntent);
        view.get().finish();
    }

    public void onRequestPermissionsResult() {
        if (PermissionHelper.hasRequiredPermissions(view.get())) {
            // now that we have permissions, we move on to checking launch options and resuming.
            checkLaunchOptions();
        } else {
            Toast.makeText(view.get(), "Camera and internet permissions needed to run this application", Toast.LENGTH_LONG)
                    .show();
            if (!PermissionHelper.shouldShowRequestPermissionRationale(view.get())) {
                // Permission denied with checking "Do not ask again".
                PermissionHelper.launchPermissionSettings(view.get());
            }
            view.get().finish();
        }
    }

    public GLSurfaceView getSurfaceView() {
        return surfaceView;
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

    public GestureDetector gestureDetector = new GestureDetector(
            view.get(),
            new GestureDetector.SimpleOnGestureListener() {
                @Override
                public boolean onSingleTapUp(final MotionEvent e) {
                    surfaceView.queueEvent(
                            () -> JniInterface.onTouched(nativeApplication, e.getX(), e.getY(), false));
                    view.get().runOnUiThread(() -> {
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
}