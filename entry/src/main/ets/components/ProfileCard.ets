// entry/src/main/ets/components/ProfileCard.ets

import { constant } from '@kit.ConnectivityKit';
import { BluetoothManager } from '../managers/BluetoothManager';

@Component
export struct ProfileCard {
  @Prop title: string = '';
  @Prop icon: string = '';
  @Prop profileType: string = '';
  @Link state: constant.ProfileConnectionState;

  private bluetoothManager: BluetoothManager = BluetoothManager.getInstance();

  build() {
    Row() {
      Column() {
        Text(this.icon)
          .fontSize(32)
      }
      .width('20%')
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#ffffff')

        Text(this.bluetoothManager.getStateText(this.state))
          .fontSize(12)
          .fontColor(this.bluetoothManager.getStateColor(this.state))
          .margin({ top: 4 })
      }
      .width('80%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .backgroundColor('#1f2937')
    .borderRadius(12)
    .padding({ left: 16, right: 16 })
    .margin({ bottom: 12 })
  }
}