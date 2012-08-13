AdaptorVMware.controllers :inodes, :priority => :low do
  before do
    logger.info('inodes#before')
    content_type 'application/json'
  end

  # Creates
  post :index do
    logger.info('inodes#index')

    uuid = params['uuid']
    @inode = Inode.new(params)
    @inode.save(uuid)
    render 'inodes/show'
  end

  get :show, "/inodes/:uuid" do
    logger.info('inodes#show')

    @inode = Inode.find_by_uuid(params[:uuid])
    render 'inodes/show'
  end

  # Reads

  # Updates
  put :index do
    logger.info('PUT - inodes#index')

    if params.present?
      uuid = params.delete('uuid')
      @inode = Inode.find_by_uuid(uuid)
      @inode.update(uuid, params) if params.present?
    end
    render 'inodes/show'
  end

  # Deletes
  delete :index do
    logger.info('DELETE - inodes#index')

    uuid = params.delete('uuid')
    @inode = Inode.find_by_uuid(uuid)
    @inode.delete(uuid)
    status 204
    render 'inodes/delete'
  end
end