AdaptorVMware.controllers :machines, :parent => :inodes do
  # include ::NewRelic::Agent::MethodTracer
  # add_method_tracer :render
  before do
    logger.info('machines#before')
    logger.debug(route.as_options[:__name__])
    content_type 'application/json'
    @inode = INode.find_by_uuid(params[:inode_id])
  end

  # Creates
  post :index do
    logger.info('POST - machines#index')
    options = params["options"]
    @machine = Machine.create(@inode, options["account_id"], options["media_store_location"], options["ovf_file_name"], options["virtual_machine_uuid"], options["network_maps"], options["disk_maps"])

    render 'machines/show'
  end

  # Reads
  get :index do
    logger.info('GET - machines#index')
    @machines = Machine.all(@inode).map { |vm| Machine.new(vm) }
    render 'machines/index'
  end

  get :index, :map => 'machines/readings' do
    logger.info('GET - machines#readings')

    _interval = params[:interval].blank? ? 300 : params[:interval]
    _since    = params[:since].blank? ? 10.minutes.ago.utc : Time.iso8601(params[:since])
    _until    = params[:until].blank? ? 5.minutes.ago.utc : Time.iso8601(params[:until])

    params[:per_page] ||= 5
    logger.info("params "+_since.to_s+" "+_until.to_s)
    @machines = Machine.all_with_readings(@inode,_interval,_since,_until).map { |vm| Machine.new(vm) }
    render 'machines/readings'

  end

  get :show, :map => "machines/:uuid" do
    logger.info('GET - machines.uuid#show')
    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    render 'machines/show'
  end

  get :index, :map => 'machines/:uuid/readings' do
    logger.info('GET - machines.uuid#readings')

    _interval = params[:interval].blank? ? 300 : params[:interval]
    _since    = params[:since].blank? ? 10.minutes.ago.utc : Time.iso8601(params[:since])
    _until    = params[:until].blank? ? 5.minutes.ago.utc : Time.iso8601(params[:until])

    @machine = Machine.find_by_uuid_with_readings(@inode, params[:uuid], _interval, _since, _until)

    render 'machines/show_readings'
  end

  # Updates
  put :show, :map => 'machines/:uuid/start' do
    logger.info('PUT - machines.uuid#start')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    logger.info @machine.inspect
    @machine.start(@inode) if @machine.present?

    render 'machines/show'
  end

  put :show, :map => 'machines/:uuid/stop' do
    logger.info('PUT - machines.uuid#stop')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    @machine.stop(@inode) if @machine.present?

    render 'machines/show'
  end

  put :show, :map => 'machines/:uuid/restart' do
    logger.info('PUT - machines.uuid#restart')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    @machine.restart(@inode) if @machine.present?

    render 'machines/show'
  end

  put :show, :map => 'machines/:uuid/force_stop' do
    logger.info('PUT - machines.uuid#force_stop')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    @machine.force_stop(@inode) if @machine.present?

    render 'machines/show'
  end

  put :show, :map => 'machines/:uuid/force_restart' do
    logger.info('PUT - machines.uuid#force_restart')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    @machine.force_restart(@inode) if @machine.present?

    render 'machines/show'
  end

  # Deletes
  delete :delete, :map => "machines/:uuid" do
    logger.info('DELETE - machines.uuid#delete')

    @machine = Machine.find_by_uuid(@inode, params[:uuid])
    @machine.delete(@inode)

    render 'machines/show'
  end
end
