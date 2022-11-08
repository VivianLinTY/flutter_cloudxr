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

#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <jni.h>

#include "hello_ar_application.h"

#define JNI_METHOD(return_type, method_name) \
  JNIEXPORT return_type JNICALL              \
      Java_com_compal_cloudxr_1flutter_JniInterface_##method_name

extern "C" {

namespace {
// maintain a reference to the JVM so we can use it later.
static JavaVM *g_vm = nullptr;

inline jlong jptr(hello_ar::HelloArApplication *native_hello_ar_application) {
  return reinterpret_cast<intptr_t>(native_hello_ar_application);
}

inline hello_ar::HelloArApplication *native(jlong ptr) {
  return reinterpret_cast<hello_ar::HelloArApplication *>(ptr);
}

}  // namespace

jint JNI_OnLoad(JavaVM *vm, void *) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

JNI_METHOD(jlong, createNativeApplication)
(JNIEnv *env, jclass, jobject j_asset_manager, jstring jcmdline) {
  AAssetManager *asset_manager = AAssetManager_fromJava(env, j_asset_manager);

  hello_ar::HelloArApplication *app = new hello_ar::HelloArApplication(asset_manager);
  if (app == nullptr)
      return 0; // can't do anything more if failed construction.

  app->Init(); // do we need a return value?

  return jptr(app);
}

JNI_METHOD(void, destroyNativeApplication)
(JNIEnv *, jclass, jlong native_application) {
  delete native(native_application);
}

JNI_METHOD(void, onPause)
(JNIEnv *, jclass, jlong native_application) {
  native(native_application)->OnPause();
}

JNI_METHOD(void, handleLaunchOptions)
(JNIEnv *env, jclass, jlong native_application, jstring jstr) {
    std::string cmdline = "";
    if (jstr != nullptr) {
        const char *cstr = env->GetStringUTFChars(jstr, nullptr);
        if (cstr != nullptr) {
            // stash the cmdline in our local string and release jni resource
            cmdline = cstr;
            env->ReleaseStringUTFChars(jstr, cstr);
        }
    }
    native(native_application)->HandleLaunchOptions(cmdline);
}

JNI_METHOD(void, setArgs)
(JNIEnv *env, jclass, jlong native_application, jstring jargs) {
  if (jargs != nullptr) {
    const char *args = env->GetStringUTFChars(jargs, nullptr);
    if (args != nullptr) {
      native(native_application)->SetArgs(args);
      env->ReleaseStringUTFChars(jargs, args);
    }
  }
}

JNI_METHOD(jstring, getServerIp)
(JNIEnv *env, jclass, jlong native_application) {
  const std::string ip = native(native_application)->GetServerIp();
  return env->NewStringUTF(ip.c_str());
}

JNI_METHOD(void, onResume)
(JNIEnv *env, jclass, jlong native_application, jobject context,
 jobject activity) {
  native(native_application)->OnResume(env, context, activity);
}

JNI_METHOD(void, onGlSurfaceCreated)
(JNIEnv *, jclass, jlong native_application) {
  native(native_application)->OnSurfaceCreated();
}

JNI_METHOD(void, onDisplayGeometryChanged)
(JNIEnv *, jobject, jlong native_application, int display_rotation, int width,
 int height) {
  native(native_application)
      ->OnDisplayGeometryChanged(display_rotation, width, height);
}

JNI_METHOD(jint, onGlSurfaceDrawFrame)
(JNIEnv *, jclass, jlong native_application) {
    return static_cast<jint>(native(native_application)->OnDrawFrame());
}

JNI_METHOD(jbyteArray, getCameraFrame)
(JNIEnv *env, jclass, jlong native_application) {
    std::vector<uint8_t> pixels = native(native_application)->getCameraFrame();
    jbyteArray arr = env->NewByteArray(pixels.size());
    env->SetByteArrayRegion(arr, 0, pixels.size(), (jbyte *) &pixels[0]);
    return arr;
}

JNI_METHOD(void, onTouched)
(JNIEnv *, jclass, jlong native_application, jfloat x, jfloat y,
    jboolean longPress) {
  native(native_application)->OnTouched(x, y, longPress);
}

JNI_METHOD(jboolean, hasDetectedPlanes)
(JNIEnv *, jclass, jlong native_application) {
  return static_cast<jboolean>(
      native(native_application)->HasDetectedPlanes() ? JNI_TRUE : JNI_FALSE);
}

JNI_METHOD(jboolean, hasCloudXrAnchor)
(JNIEnv *, jclass, jlong native_application) {
    return static_cast<jboolean>(
            native(native_application)->HasCloudXrAnchor() ? JNI_TRUE : JNI_FALSE);
}

//JNI_METHOD(jobject, getHeadPose)
//(JNIEnv *env, jclass, jlong native_application) {
//    jclass vectorClass = env->FindClass("java/util/Vector");
//    jclass floatClass = env->FindClass("java/lang/Float");
//
//    jmethodID mid = env->GetMethodID(vectorClass, "<init>", "()V");
//    jobject vector = env->NewObject(vectorClass, mid);
//    jmethodID addMethodID = env->GetMethodID(vectorClass, "add", "(Ljava/lang/Object;)Z");
//
//    std::vector<float> vec = native(native_application)->GetHeadPose();
//    for(float f : vec) {
//        jmethodID floatConstructorID = env->GetMethodID(floatClass, "<init>", "(F)V");
//        // Now, we have object created by Float(f)
//        jobject floatValue = env->NewObject(floatClass, floatConstructorID, f);
//        env->CallBooleanMethod(vector, addMethodID, floatValue);
//    }
//    return vector;
//}

JNIEnv *GetJniEnv() {
  JNIEnv *env;
  jint result = g_vm->AttachCurrentThread(&env, nullptr);
  return result == JNI_OK ? env : nullptr;
}

jclass FindClass(const char *classname) {
  JNIEnv *env = GetJniEnv();
  return env->FindClass(classname);
}

}  // extern "C"
