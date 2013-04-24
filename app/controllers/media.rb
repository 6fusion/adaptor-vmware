AdaptorVMware.controllers :media, :parent => :inodes do
  before do
    logger.info('media#before')
    logger.debug(route.as_options[:__name__])
    content_type 'application/json'
    @inode = INode.find_by_uuid(params[:inode_id])
    logger.info(params)
  end

  get :index do
    logger.info('GET - media#index')
    @medium = Medium.parse_descriptor_file(@inode, params[:medium_descriptor_location])

    render 'media/show'
  end

  delete :index do
    logger.info('DELETE - media#delete')
    @medium = Medium.delete(@inode, params[:medium_location])

    render 'media/delete'
  end
end
