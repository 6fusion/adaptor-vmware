AdaptorVMware.controllers :media_files, :parent => :inodes do
	before do
    logger.info('media_files.before')
    content_type 'application/json'
    @inode = INode.find_by_uuid(params[:inode_id])
  end

	# create / import
  post :index do
  	logger.info("POST - media_files.index")

  	datastores = @inode.hypervisor.datastores


  end
end