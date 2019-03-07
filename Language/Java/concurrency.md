## wait()、notify()实现两个线程交替答应数字
```java
/* main class */
import java.util.*;
import java.lang.*;

public class Practice {
    public static void main(String[] args) {
        MultiThread print = new MultiThread();
        Thread odd = new Thread(print::PrintOdd);
        Thread even = new Thread(print::PrintEven);
        odd.start();
        while(print.num == 1){}
        even.start();
    }
}


/* multi thread class */
import java.lang.Thread;

public class MultiThread {
    public int num = 0;
    public synchronized void PrintOdd() {
        for (int i = 0; i < 50; i++) {
            System.out.println("Thread odd: " + (++num));
            this.notify();
            try {
                this.wait();
                Thread.sleep(100);
            } catch (Exception e) {
                //todo
            }
        }
    }

    public synchronized void PrintEven() {
        for (int i = 0; i < 50; i++) {
            System.out.println("Thread even: " + (++num));
            this.notify();
            try {
                this.wait();
                Thread.sleep(100);
            } catch (Exception e) {
                //todo
            }
        }
    }
}


```
