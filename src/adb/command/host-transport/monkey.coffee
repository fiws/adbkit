once = require 'once'

Command = require '../../command'
Protocol = require '../../protocol'

class MonkeyCommand extends Command
  RE_OK = /^:Monkey:/

  execute: (port, callback) ->
    @parser.readAscii 4, (reply) =>
      switch reply
        when Protocol.OKAY
          done = once (err) ->
            raw.removeListener 'end', endListener
            clearTimeout timer
            callback err
          # The monkey command is a bit weird in that it doesn't look like it
          # starts in daemon mode, but it actually does. So even though the
          # command leaves the terminal "hanging", Ctrl-C (or just ending the
          # connection) will not end the daemon. HOWEVER, on some devices, such
          # as SO-02C by Sony, it is required to leave the command hanging
          # around. In any case, if the command exits by itself, it means that
          # something went wrong.
          raw = @parser.raw()
          # The command exited, which means that something went wrong.
          raw.once 'end', endListener = ->
            done new Error 'Unexpected end of stream'
          # If there's output, act on it.
          raw.once 'data', (chunk) =>
            if RE_OK.test chunk
              done null
            else
              done this._unexpected chunk
          # On some devices (such as F-08D by Fujitsu), the monkey command
          # gives no output no matter how many verbose flags you give it. So
          # we use a fallback timeout.
          timer = setTimeout done, 500
        when Protocol.FAIL
          @parser.readError callback
        else
          callback this._unexpected reply
    # Some devices have broken /sdcard (i.e. /mnt/sdcard), which monkey will
    # attempt to use to write log files to. We can cheat and set the location
    # with an environment variable, because most logs use
    # Environment.getLegacyExternalStorageDirectory() like they should. There
    # are some hardcoded logs, though. Anyway, this should enable most things.
    # Check https://github.com/android/platform_frameworks_base/blob/master/
    # core/java/android/os/Environment.java for the variables.
    this._send "shell:EXTERNAL_STORAGE=/data/local/tmp monkey --port #{port} -v"

module.exports = MonkeyCommand
