AdaptorVMware.controllers :machines, :map => "/inodes/:inode_uuid" do
  before do
    logger.info('machines#before')

    content_type 'application/json'
    @inode = INode.find_by_uuid(params[:inode_uuid])
  end

  # Creates
  post :index do
    begin
      logger.info('POST - machines#index')
      logger.debug "ACCEPT: #{request.accept}"

      @inode.open_session
      @machines = Machine.create_from_ovf(@inode, params[:ovf])

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  # Reads
  get :index do
    begin
      logger.info('GET - machines#index')
      @inode.open_session
      @machines = Machine.vm_inventory(@inode).map {|_, vm| Machine.new(vm)}
      render 'machines/index'
    ensure
      @inode.close_session
    end
  end

  get :index, :map => 'machines/readings' do
    logger.info('GET - machines#readings')

    _interval = params[:interval].blank? ? 300 : params[:interval]
    _since    = params[:since].blank? ? 5.minutes.ago.utc : Time.iso8601(params[:since])
    _until    = params[:until].blank? ? Time.now.utc : Time.iso8601(params[:until])

    params[:per_page] ||= 5

    @machines = Machine.all_with_readings(@inode,_interval,_since,_until)
    render 'machines/readings'

    #if params[:session_id].nil?
    #  @session_id = ResultCache.session_id
    #  ResultCache.new.put(@session_id, Machine.new.background(:ttl => 10*60*1000).all_with_readings(@inode, _interval, _since, _until))
    #  status 102
    #  body @session_id.to_s
    #else
    #  @future = ResultCache.new.get(params[:session_id])
    #  case
    #    when @future.complete?
    #      @machines = @future.result
    #      render 'machines/readings'
    #    when @future.error?
    #      raise Exceptions::Unrecoverable.new(@future.error)
    #    else
    #      status 102
    #      headers "Retry-After" => 5
    #      body params[:session_id].to_s
    #  end
    #end
    #@machines = Kaminari::paginate_array(Machine.all_with_readings(@inode, _interval, _since, _until)).page(params[:page]).per(params[:per_page])
    #render 'machines/readings'
  end

  get :show, :map => "machines/:uuid" do
    begin
      logger.info('GET - machines.uuid#show')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end
  get :index, :map => 'machines/:uuid/readings' do
    begin
      logger.info('GET - machines.uuid#readings')

      _interval = params[:interval].blank? ? 300 : params[:interval]
      _since    = params[:since].blank? ? 5.minutes.ago.utc : Time.iso8601(params[:since])
      _until    = params[:until].blank? ? Time.now.utc : Time.iso8601(params[:until])

      @inode.open_session
      @machine = Machine.find_by_uuid_with_readings(@inode, params[:uuid], _interval, _since, _until)

      render 'machines/readings'
    ensure
      @inode.close_session
    end
  end

  # Updates
  put :show, :map => 'machines/:uuid/start' do
    begin
      logger.info('PUT - machines.uuid#start')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.start(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  put :show, :map => 'machines/:uuid/stop' do
    begin
      logger.info('PUT - machines.uuid#stop')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.stop(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  put :show, :map => 'machines/:uuid/restart' do
    begin
      logger.info('PUT - machines.uuid#restart')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.restart(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  put :show, :map => 'machines/:uuid/force_stop' do
    begin
      logger.info('PUT - machines.uuid#force_stop')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.force_stop(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  put :show, :map => 'machines/:uuid/force_restart' do
    begin
      logger.info('PUT - machines.uuid#force_restart')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.force_restart(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end

  # Deletes
  delete :delete, :map => "machines/:uuid" do
    begin
      logger.info('DELETE - machines.uuid#delete')

      @inode.open_session
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.delete(@inode)

      render 'machines/show'
    ensure
      @inode.close_session
    end
  end
end
