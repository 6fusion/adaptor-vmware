AdaptorVMware.controllers :inodes, :priority => :low do
  before do
    logger.info('inodes#before')
    content_type 'application/json'
  end

  # Creates
  post :index do
    logger.info('POST - inodes#index')

    uuid = params['uuid']
    @inode = INode.new(params)
    @inode.save(uuid)
    render 'inodes/show'
  end

  get :show, "/inodes/:uuid" do
    logger.info('inodes#show')

    @inode = INode.find_by_uuid(params[:uuid])
    render 'inodes/show'
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
  delete :index do
    logger.info('DELETE - inodes#index')

    uuid = params.delete('uuid')
    @inode = INode.find_by_uuid(uuid)
    @inode.delete(uuid)
    status 204
    render 'inodes/delete'
  end

  # Diagnostics
  get :diagnostics, "/inodes/:uuid/diagnostics" do
    logger.info('DIAGNOSTICS - inodes#index')
    content_type 'text/html'
    render 'inodes/diagnostics'
  end

  get :diagnostics, "/inodes/:uuid/diagnostics.zip" do
    begin
      logger.info('DIAGNOSTICS.ZIP - inodes#index')
      @inode = INode.find_by_uuid(params[:uuid])
      @inode.open_session
      service_instance = @inode.session.serviceInstance.content
      about = service_instance.about.props
      diag = {
        :about => service_instance.about.props.to_a,
        :statistics_levels => service_instance.perfManager.historicalInterval.to_a,
        :virtual_machine_count => Machine::all(@inode).count
      }

      begin
        t = Tempfile.new("diagnostics")
        diag_file = Tempfile.new("vcenter_diagnostics") #, "#{PADRINO_ROOT}/data/")
        diag_file.print(diag.to_yaml)
        diag_file.flush

        Zip::ZipOutputStream.open(t.path) do |z|
          Dir["#{PADRINO_ROOT}/log/*.log"].each do |lf|
            z.put_next_entry(File.basename(lf))
            z.print(IO.read(lf))
          end
          z.put_next_entry("vcenter_diagnostics.yaml")
          z.print(IO.read(diag_file.path))
        end

        send_file t.path, :type => 'application/zip',
                          :disposition => "attachment",
                          :filename => "diagnostics.zip"
      ensure
        diag_file.close
        diag_file.unlink
      end
    ensure
      @inode.close_session
    end
  end
end
