import gpio
import spi
import flash
import host.file
import host.directory
import io.data



DEFAULT-MOSI ::= gpio.Pin 23
DEFAULT-MISO ::= gpio.Pin 19
DEFAULT-CLK ::= gpio.Pin 18
DEFAULT-CS ::= gpio.Pin 5


walk-dir dir/string -> Map:
  dirstrm := directory.DirectoryStream dir
  dir-map := {dir:{"dirs":[], "files":[]}}
  while true:
    f := dirstrm.next
    if f != null:
      full-path := dir + "/$f"
      if file.is-directory full-path:
        dir-map[dir]["dirs"].add f
        dir-map[full-path] = (walk-dir full-path)
      else:
        dir-map[dir]["files"].add full-path
    else:
      break
  return dir-map



print-dir-contents dir/string depth/int --show-sys/bool=false -> none:
  dirstrm := directory.DirectoryStream dir
  pad-str := "|__>"
  blank-pad := "    "
  while true:
    f := dirstrm.next
    if f != null:
      full-path := dir + "/$f"
      if file.is-directory full-path:
        if (not show-sys) and f == "System Volume Information":
          continue
        else:
        print (blank-pad * depth) + (pad-str * (depth - 1)) +  f
        print-dir-contents full-path (depth + 1)
      else:
        //print "Depth: $depth"
        if depth - 1 == 0:
          print ((blank-pad * depth) + f)
        else:
          print ((blank-pad * depth) + (pad-str) + f)
    else:
      break


/**
SDCard class mounts the sd card directory and provides basic functionality to the files.
Common use:
  ```
    main:
      sd := SDCard.from-default
      sd.print-contents
  ```
  Example of printed contents:
    ```
    /sd:
      hello.txt
      slashonly
      noslash
      itermediatedir
          |__>finaldir
      Toit
          |__>creatednew2.txt
          |__>fromtoit.txt
          |__>creatednew.txt
          |__>Folder In Toit
              |__>fromtoit.txt
      Micropython
          |__>testfile.txt
          |__>testfile1.txt
          |__>testfile2.txt
          |__>testfile3.txt
          |__>testlog.bin
          |__>writein
          |__>210218_2.bin
          |__>210218_3.bin
          |__>210218_24bar.bin
          |__>210218_log.bin
      timestream10Text.txt
    ```
*/
class SDCard extends flash.Mount:
  path/string

  /**
  Full constructor allows you to specifiy the name of the root directory for the mount-point, the spi
  bus, and the chip select pin if you want to use something other than the default.
  */
  constructor --mount-point/string --spi-bus/spi.Bus --cs/gpio.Pin:
    path = mount-point
    super.sdcard --mount-point=mount-point --spi-bus=spi-bus --cs=cs
  
  /**
  Default constructor uses:
    ```
      DEFAULT-MOSI ::= gpio.Pin 23
      DEFAULT-MISO ::= gpio.Pin 19
      DEFAULT-CLK ::= gpio.Pin 18
      DEFAULT-CS ::= gpio.Pin 5
    ```
    to construct an instance of the SDCard class. See repo readme for wiring diagram and some notes
    on sd car breakout boards
  */
  constructor.from-default:
    path = "/sd"
    super.sdcard 
        --mount-point="/sd" 
        --spi-bus=spi.Bus 
            --miso= DEFAULT-MISO
            --mosi= DEFAULT-MOSI
            --clock= DEFAULT-CLK
        --cs= DEFAULT-CS


  /**
  Prints the contents of the sd card to the terminal.
  Example of printed contents:
    ```
    /sd:
      hello.txt
      slashonly
      noslash
      itermediatedir
          |__>finaldir
      Toit
          |__>creatednew2.txt
          |__>fromtoit.txt
          |__>creatednew.txt
          |__>Folder In Toit
              |__>fromtoit.txt
      Micropython
          |__>testfile.txt
          |__>testfile1.txt
          |__>testfile2.txt
          |__>testfile3.txt
          |__>testlog.bin
          |__>writein
          |__>210218_2.bin
          |__>210218_3.bin
          |__>210218_24bar.bin
          |__>210218_log.bin
      timestream10Text.txt
    ```
    optional --show-sys argument is false by default and will not show system volumes.
    If true, it will print system volumes.
  */
  print-contents --show-sys/bool=false -> none:
    print "$this.path:"
    print-dir-contents this.path 1 --show-sys=show-sys
  
   /**
  Recursively walks the directory and returns a list of all of the contents on the
  sd card with full path specified.
  Ex:
    ```
      sd.list-contents.do: print it
    ```
    yields:
    ```
      /sd/System Volume Information
      /sd/System Volume Information/WPSettings.dat
      /sd/System Volume Information/IndexerVolumeGuid
      /sd/hello.txt
      /sd/slashonly
      /sd/noslash
      /sd/Toit
      /sd/Toit/creatednew2.txt
      /sd/Toit/fromtoit.txt
      /sd/Toit/creatednew.txt
      /sd/Toit/Folder In Toit
      /sd/Toit/Folder In Toit/fromtoit.txt
      /sd/Micropython
      /sd/Micropython/testfile.txt
      /sd/Micropython/testfile1.txt
      /sd/Micropython/testfile2.txt
      /sd/Micropython/testfile3.txt
      /sd/Micropython/testlog.bin
      /sd/Micropython/writein
      /sd/Micropython/210218_2.bin
      /sd/Micropython/210218_3.bin
      /sd/Micropython/210218_24bar.bin
      /sd/Micropython/210218_log.bin
      /sd/timestream10Text.txt
    ```
    Shows all items including system volumes.
  */
  list-contents dir/string=this.path -> List:
    dirstrm := directory.DirectoryStream dir
    dir-list := []
    while true:
      f := dirstrm.next
      if f != null:
        full-path := dir + "/$f"
        if file.is-directory full-path:
          dir-list.add full-path
          dir-list.add-all (list-contents full-path)
        else:
          dir-list.add full-path
      else:
        break
    return dir-list
  /**
  Recursively walks the directory and returns a list of all of the contents on the
  sd card and returns the path parts in a list.
  Ex:
    ```
      sd.list-contents.do: print it
    ```
    yields:
    ```
      [sd, System Volume Information]
      [sd, System Volume Information, WPSettings.dat]
      [sd, System Volume Information, IndexerVolumeGuid]
      [sd, hello.txt]
      [sd, slashonly]
      [sd, noslash]
      [sd, Toit]
      [sd, Toit, creatednew2.txt]
      [sd, Toit, fromtoit.txt]
      [sd, Toit, creatednew.txt]
      [sd, Toit, Folder In Toit]
      [sd, Toit, Folder In Toit, fromtoit.txt]
      [sd, Micropython]
      [sd, Micropython, testfile.txt]
      [sd, Micropython, testfile1.txt]
      [sd, Micropython, testfile2.txt]
      [sd, Micropython, testfile3.txt]
      [sd, Micropython, testlog.bin]
      [sd, Micropython, writein]
      [sd, Micropython, 210218_2.bin]
      [sd, Micropython, 210218_3.bin]
      [sd, Micropython, 210218_24bar.bin]
      [sd, Micropython, 210218_log.bin]
      [sd, timestream10Text.txt]
    ```
    Shows all items including system volumes.
  */
  list-content-parts dir/string=this.path -> List:
    contents := list-contents dir
    return contents.map: it.split "/" --drop-empty=true

  /**
  Utility function used so that you can pass path arguments to other functions in any of the following forms:
    /root/targetdir/.../targetfile
    root/targetdir/.../targetfile
    targetdir/.../targetfile
  and the functions should work the same for all options.
  */
  full-dir-path dir/string -> string:
    if not dir.starts-with this.path:
      if dir.starts-with "/":
        dir = (this.path + dir) 
      else:
        dir = (this.path + "/" + dir)
    return dir

  /**
    Function for making a new directory. You just specify the path of the directory. By default
    does not recursively make the needed intermediate directories if they don't exist. Pass
    --recursive=true if you desire this behavior.
  */      
  mkdir dir/string --recursive/bool=false -> none:
    dir = full-dir-path dir
    err := catch: directory.mkdir dir --recursive=recursive
    if err:
      print "Directory not created due to error: $err"
  /**
    Function for removing a directory. You just specify the path of the directory. By default
    does not recursively remove directories. Pass --recursive=true if you desire this behavior.
  */
  rmdir dir/string --recursive/bool=false -> none:
    dir = full-dir-path dir
    err := catch: directory.rmdir dir --recursive=recursive
    if err:
      print "Directory not removed due to error: $err"

    /**
    Write data to the given path. Creates the file if it doesn't exist.
    WARNING:
    If the file exists, the data will be OVERWRITTEN. 
    Use ```SDCard.append``` if you want to append data and not overwrite. 
    */
  write data/data.Data path/string  -> none:
    path = full-dir-path path
    file.write-content data --path=path --permissions=(file.CREAT | file.WRONLY)


  /**
  Appends data to the given file.
  */
  append data/data.Data path/string -> none:
    path = full-dir-path path
    err := catch: file.write-content data --path=path --permissions=(file.APPEND | file.RDWR)
    if err:
      print "File not appended due to error: $err"

  /**
  Reads data from the given path and returns the byte array. By default, reads all of the data.
  If you need more fine-grained control, see https://libs.toit.io/io/reader/class-CloseableReader.
  */
  read path/string -> ByteArray:
    path = full-dir-path path
    return file.read-content path

  /**
  Convenience function to read the data from the given path and returns it as a string.
  */
  read-str path/string -> string:
    path = full-dir-path path
    return (this.read path).to-string