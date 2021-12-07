# unbind  first board
echo -n  3-11.2:1.1 >  /sys/bus/usb/drivers/ftdi_sio/unbind 
echo -n  3-11.1:1.0 >  /sys/bus/usb/drivers/ftdi_sio/unbind 
echo -n  3-11.1:1.1  >  /sys/bus/usb/drivers/ftdi_sio/unbind 
echo -n  3-11.3:1.0  >  /sys/bus/usb/drivers/ftdi_sio/unbind 
echo -n  3-11.4:1.0  >  /sys/bus/usb/drivers/ftdi_sio/unbind 

# bind  first board
echo -n  3-11.2:1.1 >  /sys/bus/usb/drivers/ftdi_sio/bind 
echo -n  3-11.1:1.0 >  /sys/bus/usb/drivers/ftdi_sio/bind 
echo -n  3-11.1:1.1  >  /sys/bus/usb/drivers/ftdi_sio/bind 
echo -n  3-11.3:1.0  >  /sys/bus/usb/drivers/ftdi_sio/bind 
echo -n  3-11.4:1.0  >  /sys/bus/usb/drivers/ftdi_sio/bind 


#disable second board
echo -n  3-12:1.0   >  /sys/bus/usb/drivers/ftdi_sio/unbind 
echo -n  3-12:1.1   >  /sys/bus/usb/drivers/ftdi_sio/unbind 

#enable second board
echo -n  3-12:1.0   >  /sys/bus/usb/drivers/ftdi_sio/bind 
echo -n  3-12:1.1   >  /sys/bus/usb/drivers/ftdi_sio/bind 

