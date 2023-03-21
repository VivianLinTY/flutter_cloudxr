const deviceTypeHelmet = 1;
const deviceTypeMobile = 2;

const centralCodeSuccess = 0;
const centralCodeNoResource = 100;
const centralCodeEdgeDisconnected = 101;
const centralCodeLoginDuplicate = 120;
const centralCodeResourceOccupied = 121;
const centralCodeResourceNoSetup = 122;
const centralCodeTimeout = 140;
const centralCodeNoStreamVr = 141;
const centralCodeNoCloudXr = 142;
const centralCodeUnknownError = 200;
const centralCodeParamsError = 201;
const centralCodeTokenInvalid = 202;
const centralCodeAccountPwdInvalid = 203;

const edgeCodeUnassigned = 0;
const edgeCodeInitial = 110;
const edgeCodeDisconnected = 120;
const edgeCodeConnected = 130;
const edgeCodeStartingApp = 140;
const edgeCodePlaying = 150;
const edgeCodeStoppingApp = 160;
const edgeCodeReleasing = 170;

const deviceCodeUnassigned = 0;
const deviceCodeDisconnected = 120;
const deviceCodeConnected = 130;
const deviceCodePlaying = 150;

//API Tags
const TAG_ACCOUNT = 'account';
const TAG_PASSWORD = 'password';
const TAG_DEVICE_TYPE = 'device_type';
const TAG_UUID = 'uuid';
const TAG_DEVICE_STATUS = 'device_status';
const TAG_STATUS_DESC = 'status_des';
const TAG_RESPONSE_CODE = 'resp_code';
const TAG_EDGE_STATUS = 'edge_status';
const TAG_DATA = 'data';
const TAG_TOKEN = 'token';
const TAG_AUTHORIZATION = 'authorization';
const TAG_GAME_SERVER_IP = 'game_server_ip';
const TAG_TOTAL_NUMBER = 'total_num';
const TAG_APP = 'app';
const TAG_ERROR = 'error';
const TAG_DESCRIPTION = 'description';
const TAG_EDGE = "edge";
const TAG_STATUS = "status";

class Constants {
  static String getCentralCodeError(int code) {
    switch (code) {
      case centralCodeNoResource:
        return "No available resources.";
      case centralCodeEdgeDisconnected:
        return "Edge disconnected.";
      case centralCodeTimeout:
        return "Time out";
      case centralCodeNoStreamVr:
        return "StreamVR error.";
      case centralCodeNoCloudXr:
        return "CloudXR error.";
      case centralCodeResourceNoSetup:
        return "The resource has no setup.";
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
      case edgeCodeDisconnected:
        return "XR device disconnected.";
      case edgeCodeConnected:
        return "XR device connected.";
      case edgeCodeStartingApp:
        return "Starting app...";
      case edgeCodePlaying:
        return "Playing...";
      case edgeCodeStoppingApp:
        return "Stopping app...";
      case edgeCodeReleasing:
        return "Releasing";
    }
    return "";
  }
}
