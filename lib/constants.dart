const deviceTypeHelmet = 1;
const deviceTypeMobile = 2;

const centralCodeSuccess = 0;
const centralCodeNoResource = 100;
const centralCodeNoDevice = 101;
const centralCodeNoStreamVr = 102;
const centralCodeNoCloudXr = 103;
const centralCodeLoginDuplicate= 104;
const centralCodeResourceOccupied = 105;
const centralCodeUnknownError = 200;
const centralCodeParamsError = 201;
const centralCodeTokenInvalid = 202;
const centralCodeAccountPwdInvalid = 203;

const edgeCodeUnassigned = 100;
const edgeCodeInitial = 110;
const edgeCodeProcessing = 120;
const edgeCodeDisconnected = 130;
const edgeCodeConnected = 140;
const edgeCodeStartingApp = 150;
const edgeCodeAppRunning = 160;
const edgeCodePlaying = 170;

const deviceCodeUnassigned = 100;
const deviceCodeDisconnected = 130;
const deviceCodeConnected = 140;
const deviceCodePlaying = 170;

class Constants {
  static String getCentralCodeError(int code) {
    switch (code) {
      case centralCodeNoResource:
        return "No available resources.";
      case centralCodeNoDevice:
        return "Devices error.";
      case centralCodeNoStreamVr:
        return "StreamVR error.";
      case centralCodeNoCloudXr:
        return "CloudXR error.";
      case centralCodeLoginDuplicate:
        return "Duplicate login.";
      case centralCodeResourceOccupied:
        return "Resource is occupied.";
      case centralCodeUnknownError:
        return "Unknown error.";
      case centralCodeParamsError:
        return "Parameter error.";
      case centralCodeTokenInvalid:
        return "Token invalid.";
      case centralCodeAccountPwdInvalid:
        return "Account or password invalid.";
    }
    return "";
  }

  static String getEdgeStatus(int code) {
    switch (code) {
      case edgeCodeUnassigned:
        return "Unassigned.";
      case edgeCodeInitial:
        return "Initialing...";
      case edgeCodeProcessing:
        return "Processing...";
      case edgeCodeDisconnected:
        return "XR device disconnected.";
      case edgeCodeConnected:
        return "XR device connected.";
      case edgeCodeStartingApp:
        return "Starting app...";
      case edgeCodeAppRunning:
        return "App running...";
      case edgeCodePlaying:
        return "Playing...";
    }
    return "";
  }
}
