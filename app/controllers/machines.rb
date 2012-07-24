AdaptorVMware.controllers :machines, :map => "/inodes/:inode_uuid" do
  before do
    @i_node = INode.find_by_uuid(params[:inode_uuid])
  end

  # Creates
  post :create do
    begin
      @i_node.open_session
      @machine = Machine.new(params)
      @machine.save(@i_node)

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  # Reads
  get :index do
    begin
      @i_node.open_session
      @machines = Machine.all(@i_node)

      render 'machines/index'
    ensure
      @i_node.close_session
    end
  end

  get :index, :map => 'machines/readings' do
    begin
      @i_node.open_session
      @machines = Machine.all_with_readings(@i_node)

      render 'machines/readings'
    ensure
      @i_node.close_session
    end
  end

  get :show, :map => "machines/:uuid" do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end
  get :index, :map => 'machines/:uuid/readings' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid_with_readings(@i_node, params[:uuid])

      render 'machines/readings'
    ensure
      @i_node.close_session
    end
  end

  # Updates
  put :show, :map => 'machines/:uuid/power_on' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.power_on(@i_node) if @machine.present?

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  put :show, :map => 'machines/:uuid/power_off' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.power_off(@i_node) if @machine.present?

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  put :show, :map => 'machines/:uuid/restart' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.restart(@i_node) if @machine.present?

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  put :show, :map => 'machines/:uuid/shutdown' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.shutdown(@i_node) if @machine.present?

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  put :show, :map => 'machines/:uuid/unplug' do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.unplug(@i_node) if @machine.present?

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end

  # Deletes
  delete :delete, :map => "machines/:uuid" do
    begin
      @i_node.open_session
      @machine = Machine.find_by_uuid(@i_node, params[:uuid])
      @machine.delete(@i_node)

      render 'machines/show'
    ensure
      @i_node.close_session
    end
  end
end
