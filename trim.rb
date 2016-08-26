require 'kommando'
`reset`

$data_path = "$HOME/Library/Containers/com.docker.docker/Data/com.docker.driver.amd64-linux"
$syslog_path = "#{$data_path}/syslog"
$image_path = "#{$data_path}/Docker.qcow2"
$trimmed_image_path = "#{$image_path}.trimmed"

def ensure_docker_is_running
  running = (Kommando.run("$ ps ax | grep com.docker.osx.hyperkit.linux").out == "")
  return if running

  Kommando.run "$ open -b com.docker.docker"

  k = Kommando.new "$ tail -n 0 -f #{$syslog_path}"
  k.run_async
  has_started = false
  k.out.on /daemon.info chronyd: Selected source/ do
    has_started = true
  end

  until has_started do
    puts "waiting for Docker to start..."
    sleep 1
  end

  k.kill
end

def get_image_size
  Kommando.run("$ du -h #{$image_path}").out
end

def kill_all_screens
  Kommando.run "$ screen -list | grep Detached | awk '{print $1}' | cut -d '.' -f 1 | xargs kill"
end

def login_to_moby_and_zero_empty_disk
  k = Kommando.new "$ screen #{$data_path}/tty", {
    output: true
  }

  k.run_async

  sleep 1
  k.in << "\n"

  limbo_thread = Thread.new do
    sleep 2
    k.in << "\x03\n"
  end

  k.out.on /moby login:/ do
    k.in << "root\n"
  end

  k.out.on /moby:~#/ do
    limbo_thread.kill

    done_filling = false
    k.out.on /zerofile: No such file or directory|No space left on device/ do
      done_filling = true
      k.in << "ls -lah /var\n"

      k.in << "\x01ky\n"
    end

    Thread.new do
      until done_filling do
        sleep 1
        k.in << "du -h /var/zerofile\n"
      end
    end

    k.in << "reset\n"
    k.in << "df -h\n"
    k.in << "(dd if=/dev/zero of=/var/zerofile bs=1M count=#{$megabytes}; rm /var/zerofile; ls /var/zerofile) &\n"
  end

  k.wait
end

def stop_docker
  k = Kommando.run "$ killall Docker"
  until Kommando.run("$ ps ax | grep [c]om.docker.osx.hyperkit.linux").out == "" do
    puts "waiting.."
    sleep 1
  end
end

def trim_disk
  k = Kommando.run_async "$ /Applications/Docker.app/Contents/MacOS/qemu-img convert -O qcow2 #{$image_path} #{$trimmed_image_path}", {
    output: true
  }

  until k.code do
    du_k = Kommando.run "$ du -h #{$trimmed_image_path}"
    puts du_k.out if du_k.code == 0
    sleep 3
  end

  k.wait
  raise "Trimming was not success." unless k.code == 0
end

def replace_disk_with_trimmed_disk
  k = Kommando.run "$ mv #{$trimmed_image_path} #{$image_path}", {
    output: true
  }
end

puts "Current size of the image:"
before_size = get_image_size
puts before_size


gigs = unless ARGV[0]
  print "\nHow many gigs you want to trim?: "
  gets.to_f
else
  ARGV[0].to_f
end

$megabytes = (gigs * 1024).to_i

puts "Stopping Docker..."
stop_docker

puts "Starting Docker again..."
ensure_docker_is_running

kill_all_screens
login_to_moby_and_zero_empty_disk
`reset`

puts "Stopping Docker..."
stop_docker

puts "Trimming the disk, this will take a while..."
trim_disk
puts "Replacing old disk with the trimmed one..."
replace_disk_with_trimmed_disk

puts "-"*80
puts ""
puts "Before trim size:"
puts before_size
puts "After trim size:"
puts get_image_size
