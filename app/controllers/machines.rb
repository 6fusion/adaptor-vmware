AdaptorVMware.controllers :machines, :map => "/inodes/:inode_uuid" do
  before do
    logger.info('machines#before')
    content_type 'application/json'
    @inode = Inode.find_by_uuid(params[:inode_uuid])
  end

  # Creates
  post :index do
    begin
      logger.info('POST - machines#index')
      @inode.open_session
      @machine = Machine.new(params)
      @machine.save(@inode)

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
      @machines = Machine.all(@inode)

      render 'machines/index'
    ensure
      @inode.close_session
    end
  end

  get :index, :map => 'machines/readings' do
    begin
      logger.info('GET - machines#readings')
      @inode.open_session
      @machines = Machine.all_with_readings(@inode)

      render 'machines/readings'
    ensure
      @inode.close_session
    end
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
      @inode.open_session
      @machine = Machine.find_by_uuid_with_readings(@inode, params[:uuid])

      render 'machines/readings'
    ensure
      @inode.close_session
    end
  end

  # Updates
  put :show, :map => 'machines/:uuid/start' do
    begin
      logger.info('GET - machines.uuid#start')
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
      logger.info('GET - machines.uuid#force_stop')
      @machine = Machine.find_by_uuid(@inode, params[:uuid])
      @machine.force_start(@inode) if @machine.present?

      render 'machines/show'
    ensure
      @inode.close_session
  end
  end

  put :show, :map => 'machines/:uuid/force_restart' do
    begin
      logger.info('GET - machines.uuid#force_restart')
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

      status 204
      render 'machines/show'
    ensure
      @inode.close_session
    end
  end
end
