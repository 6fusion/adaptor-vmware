require 'java'
Dir['lib/java/**/*.jar'].each do |jar|
  $CLASSPATH << jar
  require jar
end
$CLASSPATH << "#{PADRINO_ROOT}/lib/java"
java_import "com.vmware.vim25.InvalidLogin"

AdaptorVMware.controllers :inodes, :priority => :low do
  before do
    logger.info('inodes#before')
    content_type 'application/json'
  end

  get :index, :provides => [:json, :html] do
    @inodes = []
    Dir["#{PADRINO_ROOT}/data/*.json"].each do |i|
      temp = ActiveSupport::JSON.decode(IO.read(i))
      @inodes << INode.find_by_uuid(temp["uuid"])
    end

    case content_type
    when :html then
      content_type 'text/html'
      render 'inodes/list'
    else
      render 'inodes/index'
    end
  end

  # Creates
  post :index do
    logger.info('POST - inodes#index')
    logger.debug(params.inspect)

    uuid = params['uuid']
    @inode = INode.new(params)
    @inode.save(uuid)
    render 'inodes/show'
  end

  get :show, "/inodes/:uuid", :provides => [:json, :html] do
    logger.info('inodes#show')

    @inode = INode.find_by_uuid(params[:uuid])

    case content_type
    when :html then
      logger.info('DIAGNOSTICS - inodes#index')
      content_type 'text/html'
      render 'inodes/diagnostics'
    else
      content_type 'application/json'
      render 'inodes/show'
    end
  end

  # Reads

  # Updates
  put :index do
    logger.info('PUT - inodes#index')

    if params.present?
      uuid = params.delete('uuid')
      @inode = INode.find_by_uuid(uuid)
      @inode.update(uuid, params) if params.present?
    end
    render 'inodes/show'
  end

  # Deletes
  delete :index, "/inodes/:uuid" do
    logger.info('DELETE - inodes#index')

    uuid = params.delete('uuid')
    @inode = INode.find_by_uuid(uuid)
    @inode.delete(uuid)
    status 204
    render 'inodes/delete'
  end

  get :diagnostics, "/inodes/:uuid/diagnostics.zip" do
    logger.info('DIAGNOSTICS.ZIP - inodes#index')
    diag = {
      :about => "Not Available",
      :statistics_levels => "Not Available",
      :virtual_machines => "Not Available"
    }
    begin
      @inode = INode.find_by_uuid(params[:uuid])
      diag[:about] = @inode.about
    rescue InvalidLogin => e
      diag[:about] = "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      diag[:about] = "Unable to connect ("+e.to_s+")"
    ensure
      @inode.close_connection
    end

    begin
      diag[:statistics_levels] = @inode.statistics_levels.to_a
    rescue InvalidLogin => e
      diag[:statistics_levels] = "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      diag[:statistics_levels] = "Unable to connect ("+e.to_s+")"
    ensure
      @inode.close_connection
    end

    begin
      diag[:virtual_machines] = @inode.virtual_machines.to_yaml
    rescue InvalidLogin => e
      diag[:virtual_machines] = "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      diag[:virtual_machines] = "Unable to connect ("+e.to_s+")"
    ensure
      @inode.close_connection
    end
    @inode.close_connection

    begin
      diag[:sessions] = @inode.vmware_api_adaptor.get_session_info.to_yaml
    rescue InvalidLogin => e
      diag[:sessions] = "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      diag[:sessions] = "Unable to connect ("+e.to_s+")"
    ensure
      @inode.close_connection
    end
    @inode.close_connection

    begin
      logger.info("DIAGNOSTICS.ZIP - #{PADRINO_ROOT}/tmp/diagnostics")
      t = Tempfile.new("diagnostics", "#{PADRINO_ROOT}/tmp")
      diag_file = Tempfile.new("vcenter_diagnostics", "#{PADRINO_ROOT}/tmp")
      diag_file.print(diag.to_yaml)
      diag_file.flush

      # Unable to zip these due to permissions
        # :cron => "/var/log/cron",
        # :messages => "/var/log/messages"
      file_list = {
        :torquebox => "/var/log/torquebox/torquebox.log"
      }

      cmd_list = {
        :date => "date -u",
        :process_list => "ps faux",
        :free_memory => "free",
        :file_system => "df -h",
        :iptables => "iptables -L",
        :network => "ifconfig -a",
        :ping_api => "ping -c 4 api.6fusion.com",
        :ping_control_room => "ping -c 4 control-room.6fusion.com"
      }

      Zip::ZipOutputStream.open(t.path) do |z|
        # add temp vcenter diagnostics files
        z.put_next_entry("vcenter_diagnostics.yaml")
        z.print(IO.read(diag_file.path))

        # dump available system logs to temp files and store them in the zip
        file_list.each do |k, c|
          if File.exists?(c) || File.zero?(c)
            logger.info('DIAGNOSTICS.ZIP - Adding '+c)
            temp = File.open(c)
            z.put_next_entry(k.to_s)
            z.print(IO.read(temp.path))
          else
            logger.info('DIAGNOSTICS.ZIP - Skipping '+c)
          end
        end

        # dump command output to temp files and store them in the zip
        cmd_list.each do |k, c|
          begin
            temp = Tempfile.new(k.to_s, "#{PADRINO_ROOT}/tmp")
            temp.print(`#{c}`)
            temp.flush
            z.put_next_entry(k.to_s)
            z.print(IO.read(temp.path))
          ensure
            temp.close
            temp.unlink
          end
        end
      end

      content_type 'application/zip'
      send_file t.path, :type => 'application/zip',
                        :disposition => "attachment",
                        :filename => "diagnostics.zip"
                           rescue InvalidLogin => e

    rescue InvalidLogin => e
      raise Exceptions::Forbidden, "Invalid Login"
    rescue => e
      logger.error(e.message)
      logger.error(e.backtrace)
      raise Exceptions::Unrecoverable, e.to_s
    ensure
      diag_file.close
      diag_file.unlink
    end
  end
end
