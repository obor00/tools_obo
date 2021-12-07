#!/usr/bin/ruby
require 'tmpdir'

$short = false

if (ARGV[0] == "-s") then
  $short = true
  ARGV.shift
end


class Run
  attr_accessor :id, :replay, :nodes

  def initialize()
    @nodes = {}
    @replay = false
  end

  def add(node)
    if (node.replay) then
      replay = true
    end
    nodes[node.name] = node
  end

  def getMaxDuration(step)
    if (replay) then
      return -1
    else
      ret = 0
      nodes.each{|k,v|
        step_name = File.dirname(v.name)
        if (step == step_name) then
          ret = v.compute_duration if v.compute_duration > ret
        end
      }
      return ret
    end
  end

end

class Node
  attr_accessor :name, :total_duration, :compute_duration, :status, :machine, :build_cached, :replay, :level

  def initialize()
    @name = ""
    @total_duration = 0
    @compute_duration = 0
    @status = "Success"
    @machine = ""
    @build_cached = false
    @replay = false
    @level = 0
  end

  def to_s
    if ($short) then
      return "#{name}:#{status}:#{compute_duration}"
    else
      return "#{name}:#{status}:#{total_duration}:#{compute_duration}:#{machine}"
    end
  end
end

class AllNodes
  attr_reader :map_by_node_name, :runs, :steps

  def initialize()
    @map_by_node_name = {}
    @runs = []
    @steps = []
  end

  def add(run)
    runs << run
    run.nodes.each{|k, item|
      if (map_by_node_name[item.name] == nil) then
        map_by_node_name[item.name] = []
      end
      map_by_node_name[item.name] << item
      step = File.dirname(item.name)
      steps << step if (not steps.include?(step))
    }
  end

  def print()
    if ($short) then
      puts "NODE\tAVG_DURATION(min)"
    else
      puts "NODE\tNB_RUN\tNB_SUCCESS\tNB_CACHE\tNB_REPLAY\tAVG_DURATION_IN_MIN\tAVG_WAITING_TIME_IN_MIN\tMACHINES..."
    end

    max_len = 0
    map_by_node_name.each { |k, v|
      max_len = k.length if (k.length > max_len)
    }
    
    map_by_node_name.sort_by { |k, v| k }.to_h.each { |key, list|
      nbSuccess = 0
      nbReplay = 0
      nbCacheHit = 0
      totSuccessDuration = 0
      topComputeSuccessDuration = 0
      machines = ""
      list.each { |item|
        if (item.status == "Success") then
          nbSuccess += 1
          if (item.build_cached) then
            nbCacheHit += 1
          elsif (item.replay)
            nbReplay += 1
          else
            totSuccessDuration += item.total_duration
            topComputeSuccessDuration += item.compute_duration
          end
        end
        machines += "#{item.machine}:\t#{item.compute_duration}\t"
      }
      avgDuration = 0
      avgwt = 0
      nbSuccessRun = nbSuccess-nbCacheHit-nbReplay
      if (nbSuccessRun != 0) then
        avgDuration = topComputeSuccessDuration/(nbSuccessRun)
        avgwt = (totSuccessDuration-topComputeSuccessDuration)/(nbSuccessRun)
      end
      key += " " while (key.length < max_len)
      if ($short) then
        puts "#{key}\t#{avgDuration}"
      else
        puts "#{key}\t#{list.length}\t#{nbSuccess}\t#{nbCacheHit}\t#{nbReplay}\t#{avgDuration}\t#{avgwt}\t#{machines}"
      end
    }
    if (! $short) then
      puts "\tmin\tmax\tavg"
      steps.each{ |step|
        max_durations = ""
        min = nil
        max = 0
        tot = 0
        nb = 0
        runs.each{ |run|
          d = run.getMaxDuration(step)
          if (d == -1) then
            d = "n/a:Replay"
          else
            min = d if (min == nil || d < min)
            max = d if (d>max)
            tot += d
            nb += 1
          end
          max_durations += "_\t#{d}\t"
        }
        avg = 1.0*tot/nb
        key = "MAX_TIME_for_#{step}"
        key += " " while (key.length < max_len)
        puts "#{key}\t#{min}\t#{max}\t#{avg}\t\t\t\t#{max_durations}"
      }
    end
  end

end

all_nodes = AllNodes.new

def getMinutes(string)
  string = string[1..-9]
  ret = 0
  string.split(" ").each { |s|
    if (s == "hr") then
      ret = ret*60;
    elsif (s == "min") then
      break
    elsif (s == "sec") then
      ret = 0
      break
    else
      ret += s.to_i
    end
  }
  return ret
end


Dir.mktmpdir { |dir|
  ARGV.each { |arg|
    if (!arg.start_with?("https://jenkins.kalray.eu/jenkins/job/")) then
      arg = "https://jenkins.kalray.eu/jenkins/job/csw_pipeline/" + arg
    end
    if (!arg.end_with?("/flowGraphTable/", "/flowGraphTable")) then
      arg = arg + "/flowGraphTable"
    end

    `wget -q #{arg} -O flowGraphTable`
    cmd = 'cat flowGraphTable | sed \'s/\(style="padding-left: \([0-9]*\)px"\)>/\0LEVEL \2<br>/g\' | html2markdown -b 0 > steps'
    #puts cmd
    `#{cmd}`
    ni = nil
    level = 0
    stage_name = ""

    run = Run.new

    File.open("steps", "r") do |f|
      f.each_line do |line|
        if (line.start_with?("LEVEL ")) then
          level = line[6..-1].strip().to_i
          if (ni != nil && level < ni.level) then
            run.add(ni)
            ni = nil
          end
          next
        end
        if (line.start_with?("[Stage : Start -")) then
          stage_name = line[/\| ([^|]*)\|/, 1] if (ni == nil)
          next
        end
        if (line.start_with?("[Branch:")) then
          # beginning of a block
          break if (line.start_with?("[Branch: tag_and_propagate"))
          break if (line.start_with?("[Branch: publish_perfs"))
          run.add(ni) if (ni != nil)
          ni = Node.new
          ni.name = stage_name + "/" + line[/\[Branch: ([^ ]+)/,1]
          ni.level = level
          next
        end
        next if ni == nil
        if (line.include?("https://jenkins.kalray.eu/jenkins//computer")) then
          ni.machine = line[/https:\/\/jenkins.kalray.eu\/jenkins\/\/computer\/([^\/|]+)/,1]
        elsif (line.start_with?("[Copy step")) then
          puts line
          ni.replay = true
        elsif (line.start_with?("[Build cache hit!")) then
          ni.build_cached = true
        elsif (line.start_with?("[Add Error Badge")) then
          ni.status = "Failure"
        elsif (line.start_with?("[Allocate node : Start - (")) then
          next if (line.include?("| master|"))
          line.scan(/\[[^\]]*\]/) { |match|
            ni.total_duration += getMinutes(match[/\(.*?\)/])
            break
          }
        elsif (line.start_with?("[Allocate node : Body : Start - (")) then
          next if (line.include?("| master|"))
          line.scan(/\[[^\]]*\]/) { |match|
            ni.compute_duration += getMinutes(match[/\(.*?\)/])
            break
          }
        end
      end
    end
    if (ni != nil) then
      run.add(ni)
    end
    ni = nil
    all_nodes.add(run)
  }
}

all_nodes.print()


