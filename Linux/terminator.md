## The following keybindings can be used to control Terminator:

### 第一部份：关于在同一个标签内的操作
* Ctrl+Shift+O \
Split terminals Horizontally.    //水平分割终端

* Ctrl+Shift+E \
Split terminals Vertically.    //垂直分割终端

* Ctrl+Shift+Right \
Move parent dragbar Right.    //在垂直分割的终端中将分割条向右移动

* Ctrl+Shift+Left \
Move parent dragbar Left.    //在垂直分割的终端中将分割条向左移动

* Ctrl+Shift+Up \
Move parent dragbar Up.        //在水平分割的终端中将分割条向上移动

Ctrl+Shift+Down \
Move parent dragbar Down.    //在水平分割的终端中将分割条向下移动

* Ctrl+Shift+S \
Hide/Show Scrollbar.        //隐藏/显示滚动条

* Ctrl+Shift+F \
Search within terminal scrollback    //搜索

* Ctrl+Shift+N or Ctrl+Tab \
Move to next terminal within the same tab, use Ctrl+PageDown to move to the next tab. If cycle_term_tab is False, cycle within the same tab will be disabled            //Crtl+Tab   移动到下一个终端

* Ctrl+Shift+P or Ctrl+Shift+Tab \
Move to previous terminal within the same tab, use Ctrl+PageUp to move to the previous tab. If cycle_term_tab is False, cycle within the same tab will be disabled          //Crtl+Shift+Tab 移动到之前的一个终端

* Alt+Up \
Move to the terminal above the current one.    //移动到上面的终端

* Alt+Down \
Move to the terminal below the current one.    //移动到下面的终端

* Alt+Left \
Move to the terminal left of the current one.    //移动到左边的终端

* Alt+Right \
Move to the terminal right of the current one.    //移动到右边的终端

* Ctrl+Shift+C \
Copy selected text to clipboard            //复制选中的内容到剪贴板

* Ctrl+Shift+V \
Paste clipboard text                //粘贴剪贴板的内容到此处

* Ctrl+Shift+W \
Close the current terminal.            //关闭当前终端

* Ctrl+Shift+Q \
Quits Terminator                //退出当前窗口，当前窗口的所有终端都将被关闭

* Ctrl+Shift+X \
Toggle between showing all terminals and only showing the current one (maximise).    //只显示当前终端和显示所有终端的转换开关

* Ctrl+Shift+Z \
Toggle between showing all terminals and only showing a  version of the current one (zoom).    //与Crtl+Shift+X的功能基本一样，只是转换后的当前终端文字等大小不一样

### 第二部份：有关各个标签之间的操作
* Ctrl+Shift+T   \  
Open new tab    //打开一个新的标签

* Ctrl+PageDown     \
Move to next Tab    //移动到下一个标签

* Ctrl+PageUp \
Move to previous Tab    //移动到上一个标签

* Ctrl+Shift+PageDown \
Swap tab position with next Tab       //没懂这个

* Ctrl+Shift+PageUp \
Swap tab position with previous Tab    //没懂这个

* Ctrl+Plus (+) \
Increase font size. Note: this may require you to press shift, depending on your keyboard    //增大字体

* Ctrl+Minus (-) \
Decrease font size. Note: this may require you to press shift, depending on your keyboard    //减小字体

* Ctrl+Zero (0) \
Restore font size to original setting.        //恢复字体到原始大小

* F11 \
Toggle fullscreen    //全屏开关

* Ctrl+Shift+R \
Reset terminal state    //重置终端状态（未懂）

* Ctrl+Shift+G \
Reset terminal state and clear window    //重置终端状态并clear屏幕

* Super+g \
Group all terminals so that any input sent to one of them, goes to all of them.       //绑定所有的终端，以便向一个输入能够输入到所有的终端

* Super+Shift+G \
Remove grouping from all terminals.    //解除绑定

* Super+t \
Group all terminals in the current tab so input sent to one of them, goes to all terminals in the current tab.    //绑定当前标签的所有终端

* Super+Shift+T \
Remove grouping from all terminals in the current tab.    //解除绑定

* Ctrl+Shift+I \
Open a new window (note: unlike in previous releases, this window is part of the same Terminator process)    //打开一个窗口，但是有点像继承了父窗口

* Super+i \
Spawn a new Terminator process    //这个跟上一个的主要区别还没弄懂

* Drag and Drop \
The layout can be modified by moving terminals with Drag and Drop. To start dragging a terminal, click and hold on its titlebar. Alternatively, 　　hold down Ctrl, click and hold the right mouse button. Then, **Release Ctrl**. You can now drag the terminal to the point in the layout you wou　　 ld like it to be. The zone where the terminal would be inserted will be highlighted.    //用来改变窗口布局的，另外我觉得这儿是鼠标左键
