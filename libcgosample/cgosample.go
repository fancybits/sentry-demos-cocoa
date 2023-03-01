package main

import "C"
import "time"

//export cgosample_sleep
func cgosample_sleep(seconds int) {
	time.Sleep(time.Duration(seconds) * time.Second)
}

//export cgosample_a
func cgosample_a() {
	cgosample_b()
}

//export cgosample_b
func cgosample_b() {
	cgosample_sleep(3)
}

func main() {

}
