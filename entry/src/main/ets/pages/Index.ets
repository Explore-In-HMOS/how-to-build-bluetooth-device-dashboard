// entry/src/main/ets/pages/Index.ets

import { BluetoothManager } from '../managers/BluetoothManager';
import { ProfileCard } from '../components/ProfileCard';
import { constant } from '@kit.ConnectivityKit';
import { common } from '@kit.AbilityKit';

interface DeviceItem {
  deviceName: string;
  deviceAddress: string;
  isPaired: boolean;
}

@Entry
@Component
struct Index {
  private bluetoothManager: BluetoothManager = BluetoothManager.getInstance();
  @State a2dpState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  @State hfpState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  @State hidState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  @State panState: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_DISCONNECTED;
  @State deviceName: string = 'Not selected';
  @State deviceAddress: string = '';
  @State bondState: string = '';
  @State isLoading: boolean = true;
  @State isConnecting: boolean = false;
  @State isScanning: boolean = false;
  @State errorMessage: string = '';
  @State pairedDeviceList: DeviceItem[] = [];
  @State discoveredDeviceList: DeviceItem[] = [];
  @State showPairedList: boolean = true;
  @State showDiscoveredList: boolean = true;

  async aboutToAppear() {
    this.bluetoothManager.onStateChange = () => {
      this.updateUIStates();
    };
    this.bluetoothManager.onDeviceListUpdate = () => {
      this.updateDeviceLists();
    };
    await this.initializeApp();
  }

  aboutToDisappear() {
    this.bluetoothManager.cleanup();
  }

  async initializeApp() {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const hasPermissions = await this.bluetoothManager.requestPermissions(context);
      if (!hasPermissions) {
        this.errorMessage = 'Bluetooth permission not granted';
        this.isLoading = false;
        return;
      }

      const bluetoothEnabled = await this.bluetoothManager.enableBluetooth();
      if (!bluetoothEnabled) {
        this.errorMessage = 'Bluetooth must be enabled';
        this.isLoading = false;
        return;
      }

      const initSuccess = await this.bluetoothManager.initProfiles();
      if (!initSuccess) {
        this.errorMessage = 'Failed to initialize Bluetooth profiles';
        this.isLoading = false;
        return;
      }

      this.bluetoothManager.loadPairedDevices();
      this.updateDeviceLists();

      await this.startScan();

      this.isLoading = false;
    } catch (err) {
      this.errorMessage = 'Initialization failed';
      this.isLoading = false;
    }
  }

  updateUIStates() {
    this.a2dpState = this.bluetoothManager.a2dpState;
    this.hfpState = this.bluetoothManager.hfpState;
    this.hidState = this.bluetoothManager.hidState;
    this.panState = this.bluetoothManager.panState;
    this.deviceName = this.bluetoothManager.selectedDeviceName || 'Not selected';
    this.deviceAddress = this.bluetoothManager.selectedDeviceAddress;
    this.bondState = this.bluetoothManager.bondState;
    this.errorMessage = this.bluetoothManager.lastError;
    this.isScanning = this.bluetoothManager.isScanning;
  }

  updateDeviceLists() {
    this.pairedDeviceList = this.bluetoothManager.pairedDevicesList;
    this.discoveredDeviceList = this.bluetoothManager.discoveredDevicesList;
  }

  async startScan() {
    this.isScanning = true;
    this.bluetoothManager.clearDiscoveredDevices();
    const success = await this.bluetoothManager.startDeviceDiscovery();
    if (!success) {
      this.errorMessage = this.bluetoothManager.lastError;
    }
    setTimeout(() => {
      if (this.isScanning) {
        this.stopScan();
      }
    }, 15000);
  }

  async stopScan() {
    await this.bluetoothManager.stopDeviceDiscovery();
    this.isScanning = false;
  }

  selectDevice(device: DeviceItem) {
    this.bluetoothManager.selectDevice(device.deviceAddress, device.deviceName);
    this.showPairedList = false;
    this.showDiscoveredList = false;
  }

  async handleConnect() {
    this.isConnecting = true;
    this.errorMessage = '';
    await this.bluetoothManager.connectToDevice();
    this.isConnecting = false;
  }

  build() {
    Scroll() {
      Column() {
        Column() {
          Text('Bluetooth Control Center')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .margin({ top: 16, bottom: 8 });

          Text('Wearable Bluetooth Manager')
            .fontSize(12)
            .fontColor('#9ca3af')
            .margin({ bottom: 16 });
        }
        .width('100%')
        .backgroundColor('#111827')
        .borderRadius({ bottomLeft: 20, bottomRight: 20 })
        .padding({ bottom: 16 });

        Column() {
          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(48)
                .height(48)
                .color('#3b82f6')
                .margin({ top: 100 });

              Text('Initializing Bluetooth...')
                .fontSize(14)
                .fontColor('#9ca3af')
                .margin({ top: 16 });
            }
            .width('100%')
            .height(300);
          } else {
            if (this.errorMessage !== '') {
              Text(this.errorMessage)
                .fontSize(12)
                .fontColor('#ef4444')
                .textAlign(TextAlign.Center)
                .width('100%')
                .padding(12)
                .backgroundColor('#1f2937')
                .borderRadius(8)
                .margin({ bottom: 16 });
            }

            Row() {
              Button(this.isScanning ? 'Scanning...' : 'Start Scan')
                .height(40)
                .fontSize(14)
                .backgroundColor('#3b82f6')
                .borderRadius(20)
                .layoutWeight(1)
                .enabled(!this.isScanning)
                .onClick(() => this.startScan());

              Button('Stop Scan')
                .height(40)
                .fontSize(14)
                .backgroundColor('#ef4444')
                .borderRadius(20)
                .layoutWeight(1)
                .margin({ left: 12 })
                .enabled(this.isScanning)
                .onClick(() => this.stopScan());
            }
            .width('100%')
            .padding({
              left: 16,
              right: 16,
              top: 8,
              bottom: 8
            });

            Column() {
              Row() {
                Text('📱 Selected Device')
                  .fontSize(14)
                  .fontColor('#9ca3af')
                  .layoutWeight(1);

                if (this.deviceName !== 'Not selected') {
                  Button('Change')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor('#374151')
                    .borderRadius(14)
                    .onClick(() => {
                      this.showPairedList = !this.showPairedList;
                      this.showDiscoveredList = !this.showDiscoveredList;
                    });
                }
              }
              .width('100%')
              .margin({ bottom: 12 });

              if (this.deviceName !== 'Not selected') {
                Row() {
                  Text('🔵')
                    .fontSize(24)
                    .margin({ right: 12 });

                  Column() {
                    Text(this.deviceName)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#ffffff');

                    Text(`Address: ${this.deviceAddress}`)
                      .fontSize(11)
                      .fontColor('#6b7280')
                      .margin({ top: 2 });

                    Text(`Status: ${this.bondState}`)
                      .fontSize(11)
                      .fontColor('#6b7280')
                      .margin({ top: 2 });
                  }
                  .alignItems(HorizontalAlign.Start);
                };
              } else {
                Text('No device selected. Tap "Change" to select a device.')
                  .fontSize(12)
                  .fontColor('#6b7280')
                  .padding(16);
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#1f2937')
            .borderRadius(12)
            .margin({ bottom: 16 });

            if (this.deviceName !== 'Not selected' && this.bondState === 'Paired') {
              Row() {
                Button(this.isConnecting ? 'Connecting...' : 'Connect')
                  .height(44)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor('#3b82f6')
                  .borderRadius(22)
                  .layoutWeight(1)
                  .enabled(!this.isConnecting && this.a2dpState !== constant.ProfileConnectionState.STATE_CONNECTED)
                  .onClick(() => this.handleConnect());
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 16 });
            }

            if (this.pairedDeviceList.length > 0) {
              Column() {
                Row() {
                  Text(`✓ Paired Devices (${this.pairedDeviceList.length})`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#10b981');

                  Blank();

                  Button(this.showPairedList ? '▼' : '▶')
                    .width(32)
                    .height(32)
                    .backgroundColor('transparent')
                    .fontSize(16)
                    .fontColor('#9ca3af')
                    .onClick(() => {
                      this.showPairedList = !this.showPairedList;
                    });
                }
                .width('100%')
                .padding({
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 8
                });

                if (this.showPairedList) {
                  ForEach(
                    this.pairedDeviceList,
                    (item: DeviceItem, index: number) => {
                      this.DeviceListItem(item);
                    },
                    (item: DeviceItem, index: number) => item.deviceAddress
                  );
                }
              }
              .width('100%')
              .backgroundColor('#1f2937')
              .borderRadius(12)
              .margin({ bottom: 16 });
            }

            if (this.discoveredDeviceList.length > 0) {
              Column() {
                Row() {
                  Text(`🔍 Discovered Devices (${this.discoveredDeviceList.length})`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#f59e0b');

                  Blank();

                  Button(this.showDiscoveredList ? '▼' : '▶')
                    .width(32)
                    .height(32)
                    .backgroundColor('transparent')
                    .fontSize(16)
                    .fontColor('#9ca3af')
                    .onClick(() => {
                      this.showDiscoveredList = !this.showDiscoveredList;
                    });
                }
                .width('100%')
                .padding({
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 8
                });

                if (this.showDiscoveredList) {
                  ForEach(
                    this.discoveredDeviceList,
                    (item: DeviceItem, index: number) => {
                      this.DeviceListItem(item);
                    },
                    (item: DeviceItem, index: number) => item.deviceAddress
                  );
                }
              }
              .width('100%')
              .backgroundColor('#1f2937')
              .borderRadius(12)
              .margin({ bottom: 16 });
            }

            if (this.isScanning) {
              Row() {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#3b82f6');
                Text(' Scanning for devices...')
                  .fontSize(12)
                  .fontColor('#9ca3af')
                  .margin({ left: 8 });
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#1f2937')
              .borderRadius(8)
              .margin({ bottom: 16 });
            }

            Text('Bluetooth Profile States')
              .fontSize(14)
              .fontColor('#9ca3af')
              .margin({ left: 16, top: 8, bottom: 12 })
              .alignSelf(ItemAlign.Start);

            ProfileCard({
              title: 'Music Streaming (A2DP)',
              icon: '🎵',
              profileType: 'a2dp',
              state: $a2dpState
            });

            ProfileCard({
              title: 'Hands-Free Calling (HFP)',
              icon: '📞',
              profileType: 'hfp',
              state: $hfpState
            });

            ProfileCard({
              title: 'Input Peripherals (HID)',
              icon: '⌨️',
              profileType: 'hid',
              state: $hidState
            });

            ProfileCard({
              title: 'Network Sharing (PAN)',
              icon: '🌐',
              profileType: 'pan',
              state: $panState
            });

            Column() {
              Text('ℹ️ Tap "Start Scan" to find nearby Bluetooth devices')
                .fontSize(11)
                .fontColor('#6b7280')
                .textAlign(TextAlign.Center);

              Text('✓ Only paired devices can be connected')
                .fontSize(10)
                .fontColor('#4b5563')
                .textAlign(TextAlign.Center)
                .margin({ top: 4 });

              Text('📌 Tap a device to select it, then press Connect')
                .fontSize(10)
                .fontColor('#4b5563')
                .textAlign(TextAlign.Center)
                .margin({ top: 4 });
            }
            .width('100%')
            .padding(16)
            .margin({ top: 8, bottom: 20 });
          }
        }
        .width('100%');
      }
      .margin({
        top: 20
      })
      .width('100%')
      .backgroundColor('#111827');
    }
    .scrollBar(BarState.Off);
  }

  @Builder
  DeviceListItem(item: DeviceItem) {
    Row() {
      Column() {
        Text(item.isPaired ? '🔵' : '🔄')
          .fontSize(20);
      }
      .width('15%')
      .alignItems(HorizontalAlign.Center);

      Column() {
        Text(item.deviceName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#ffffff');

        Text(item.deviceAddress)
          .fontSize(10)
          .fontColor('#6b7280')
          .margin({ top: 2 });

        if (item.isPaired) {
          Text('Paired ✓')
            .fontSize(10)
            .fontColor('#10b981')
            .margin({ top: 2 });
        } else {
          Text('Not Paired')
            .fontSize(10)
            .fontColor('#f59e0b')
            .margin({ top: 2 });
        }
      }
      .width('60%')
      .alignItems(HorizontalAlign.Start);

      Column() {
        Button('Select')
          .height(32)
          .fontSize(12)
          .backgroundColor(item.isPaired ? '#3b82f6' : '#374151')
          .borderRadius(16)
          .enabled(item.isPaired)
          .onClick(() => {
            this.selectDevice(item);
          });
      }
      .width('25%')
      .alignItems(HorizontalAlign.End);
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#374151')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      if (item.isPaired) {
        this.selectDevice(item);
      }
    });
  }
}