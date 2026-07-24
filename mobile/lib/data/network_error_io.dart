import 'dart:io';

bool isIoNetworkError(Object error) => error is SocketException;
