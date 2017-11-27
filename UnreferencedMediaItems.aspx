<%@ Page Language="C#" AutoEventWireup="true" %>

<%@ Import Namespace="Sitecore" %>
<%@ Import Namespace="Sitecore.Data" %>
<%@ Import Namespace="Sitecore.Data.Archiving" %>
<%@ Import Namespace="Sitecore.Data.Items" %>
<%@ Import Namespace="Sitecore.Globalization" %>
<%@ Import Namespace="Sitecore.Links" %>
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Linq" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.UI" %>
<%@ Import Namespace="System.Web.UI.HtmlControls" %>
<%@ Import Namespace="System.Web.UI.WebControls" %>

<!DOCTYPE html>
<script language="C#" runat="server">   
     Database currentDB = null;
        private static String selectedDB = String.Empty;
        protected void Page_Init(object sender, EventArgs e)
        {
           //Space for custom logic
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            //This condition allows only Administrator to access this page.
            if (!Sitecore.Context.User.IsAdministrator)
            {
                Response.Redirect("http://" + HttpContext.Current.Request.Url.Host + "/sitecore/login?returnUrl=%2fsitecore%2fadmin%2fUnreferencedMediaItems.aspx");
            }
            lblTotalCount.Attributes.Add("display", "none");
            if (!Page.IsPostBack)
            {
                foreach (string dbname in Sitecore.Configuration.Factory.GetDatabaseNames())
                {
                    if (dbname.ToLower() != "core" && dbname.ToLower() != "filesystem")
                    {
                        ddDb.Items.Add(new ListItem(dbname));
                    }
                }
            }

        }

        private static Item[] GetLinkedItems(Database database, Language language, Item refItem)
        {
            // getting all linked Items that refer to the “refItem” Item
            ItemLink[] links = Globals.LinkDatabase.GetReferrers(refItem);
            if (links == null)
            {
                return null;
            }

            ArrayList result = new ArrayList(links.Length);

            foreach (ItemLink link in links)
            {
                // checking the database name of the linked Item
                if (link.SourceDatabaseName == database.Name)
                {
                    Item item = database.Items[link.SourceItemID, language];
                    // adding the Item to an array if the Item is not null
                    if (item != null)
                    {
                        result.Add(item);
                    }
                }
            }

            return (Item[])result.ToArray(typeof(Item));
        }

        private static int GetLinkedItemsCount(Item refItem)
        {            
            // getting all linked Items that refer to the “refItem” Item
            return Globals.LinkDatabase.GetReferrerCount(refItem);
        }

        /// <summary>
        /// Loads all unreferenced Media except the Media Folder.
        /// </summary>
        public void LoadUnreferencedItems()
        {           
            currentDB = Sitecore.Data.Database.GetDatabase(ddDb.SelectedValue);          
            if (ddDb.SelectedValue == "master")
            {
                Sitecore.Context.SetActiveSite("shell");
                currentDB = Sitecore.Context.ContentDatabase;
            }
            string mediaItemrootpath="/sitecore/media library/";
            if(!string.IsNullOrEmpty(txtmediarootpath.Text))
            {
                mediaItemrootpath=txtmediarootpath.Text;
            }
            //Get the media library item
            Item MediaLibrary = currentDB.GetItem(mediaItemrootpath);
            if (MediaLibrary != null)
            {
                lblMessage.Text = string.Empty;
                int count = 0;
                int TotalMediaCount = 0;
                List<Item> UnusedMedia = new List<Item>();
                foreach (Item MedItm in MediaLibrary.Axes.GetDescendants())
                {
                    if (MedItm!=null && MedItm.TemplateID.ToString() != "{FE5DD826-48C6-436D-B87A-7C4210C7413B}")
                    {
                        bool valid = true;
                        if (chkIncludeSystem.Checked)
                        {

                        }
                        else
                        {
                            if (MedItm.Paths.Path.ToLower().Contains("/sitecore/media library/system/"))
                                valid = false;
                        }
                        if (valid && GetLinkedItemsCount(MedItm) == 0)
                        {
                            UnusedMedia.Add(MedItm);
                            count++;
                        }
                        TotalMediaCount++;
                    }
                }
                //Count of total media items vs unreferenced media items
                lblTotalCount.Text = "Total Media item count:" + TotalMediaCount;
                lblTotalCount.Text +=  "\n Unreferenced media item Count:" + count;
                if (UnusedMedia.Count > 0)
                {
                    pnlmedias.Visible = true;
                    rptUnusedItems.DataSource = UnusedMedia;
                    rptUnusedItems.DataBind();
                }
                if (rptUnusedItems.Items.Count > 0)
                {
                    btnDelete.Enabled = true;
                    btnPermDelete.Enabled = true;
                }
            }
            else
            {
                pnlmedias.Visible = false;
                lblMessage.Text = "Specified path is not found";
                Sitecore.Diagnostics.Log.Info("Media Library is null", this);
            }
                

        }

        protected void btnGo_Click(object sender, EventArgs e)
        {
            try
            {
                LoadUnreferencedItems();
                selectedDB = ddDb.SelectedValue;
            }
            catch(Exception excp)
            {
                Sitecore.Diagnostics.Log.Error("Error while loading the list of unreferenced media items:" + excp.StackTrace, excp);
            }
        }

        /// <summary>
        /// Moves media item to Recycle Bin.
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        protected void btnDelete_Click(object sender, EventArgs e)
        {
            try
            {
                currentDB = Sitecore.Context.Database;
                if (!String.IsNullOrEmpty(selectedDB) && selectedDB == "master")
                {
                    Sitecore.Context.SetActiveSite("shell");
                    currentDB = Sitecore.Context.ContentDatabase;
                }
                foreach (RepeaterItem rptItem in rptUnusedItems.Items)
                {
                    CheckBox chkItem = (CheckBox)rptItem.FindControl("chkItem");
                    if (chkItem.Checked)
                    {
                        Label lblItemID = (Label)rptItem.FindControl("lblItemID");
                        if (!String.IsNullOrEmpty(lblItemID.Text))
                        {
                            Item itm = currentDB.GetItem(lblItemID.Text);
                            if (itm != null)
                            {
                                itm.Recycle();
                            }
                        }
                    }
                }
                if(chkRemoveMediaFolder.Checked)
                {
                    RecycleMediaFolder();
                }
                LoadUnreferencedItems();
                lblMessage.Text = "Selected item(s) has been moved to Recycle bin. You can restore the item from Recycle bin.";
            }
            catch (Exception excp)
            {
                lblMessage.Text = excp.ToString();
            }

        }




        /// <summary>
        /// Deletes the media item permanently
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        protected void btnPermDelete_Click(object sender, EventArgs e)
        {
            try
            {
                currentDB = Sitecore.Context.Database;
                if (!String.IsNullOrEmpty(selectedDB) && selectedDB == "master")
                {
                    Sitecore.Context.SetActiveSite("shell");
                    currentDB = Sitecore.Context.ContentDatabase;
                }
                foreach (RepeaterItem rptItem in rptUnusedItems.Items)
                {
                    CheckBox chkItem = (CheckBox)rptItem.FindControl("chkItem");
                    if (chkItem.Checked)
                    {
                        Label lblItemID = (Label)rptItem.FindControl("lblItemID");
                        if (!String.IsNullOrEmpty(lblItemID.Text))
                        {
                            Item itm = currentDB.GetItem(lblItemID.Text);
                            if (itm != null)
                            {
                                itm.Delete();
                            }
                        }
                    }
                }
                if(chkRemoveMediaFolder.Checked)
                {
                    DeleteMediaFolder();
                }
                LoadUnreferencedItems();
                lblMessage.Text = "Selected item(s) has been permanently deleted.";
            }
            catch (Exception excp)
            {
                lblMessage.Text = excp.ToString();
            }

        }

     /// <summary>
        /// Deletes Empty Media folders
        /// </summary>
        private void DeleteMediaFolder()
        {
            string mediaItemrootpath = "/sitecore/media library/";
            if (!string.IsNullOrEmpty(txtmediarootpath.Text))
            {
                mediaItemrootpath = txtmediarootpath.Text;
            }
            //Get the media library item
            Item MediaLibrary = currentDB.GetItem(mediaItemrootpath);

            foreach (Item MedItm in MediaLibrary.Axes.GetDescendants())
            {
                if (MedItm.TemplateID.ToString().ToUpper().Equals("{FE5DD826-48C6-436D-B87A-7C4210C7413B}") || MedItm.TemplateName.ToString().ToLower().Equals("media folder"))
                {
                    if (!MedItm.HasChildren && MedItm.Children.Count == 0)
                    {
                        MedItm.Delete();
                    }
                }
            }

        }

            /// <summary>
        /// Recycles Empty Media folders
        /// </summary>
        private void RecycleMediaFolder()
        {
            string mediaItemrootpath = "/sitecore/media library/";
            if (!string.IsNullOrEmpty(txtmediarootpath.Text))
            {
                mediaItemrootpath = txtmediarootpath.Text;
            }
            //Get the media library item
            Item MediaLibrary = currentDB.GetItem(mediaItemrootpath);

            foreach (Item MedItm in MediaLibrary.Axes.GetDescendants())
            {
                if (MedItm.TemplateID.ToString().ToUpper().Equals("{FE5DD826-48C6-436D-B87A-7C4210C7413B}") || MedItm.TemplateName.ToString().ToLower().Equals("media folder"))
                {
                    if (!MedItm.HasChildren && MedItm.Children.Count == 0)
                    {
                        MedItm.Recycle();
                    }
                }
            }

        }


        /// <summary>
        /// Deletes all the items from Recycle Bin
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        protected void btnEmptyRecycleBin_Click(object sender, EventArgs e)
        {
            string archiveName = "recyclebin";
            var database = Sitecore.Data.Database.GetDatabase(ddDb.SelectedValue); // Get content database

            Archive archive = Sitecore.Data.Archiving.ArchiveManager.GetArchive(archiveName, database);
            archive.RemoveEntries();
        }

        protected void rptUnusedItems_ItemDataBound(object sender, RepeaterItemEventArgs e)
        {
            if (e.Item.ItemType == ListItemType.Item || e.Item.ItemType == ListItemType.AlternatingItem)
            {
                HtmlAnchor lnkScreenShot = e.Item.FindControl("lnkScreenShot") as HtmlAnchor;

                if (((Item)e.Item.DataItem).Paths.IsMediaItem)
                {
                    MediaItem mditm = new MediaItem((Item)e.Item.DataItem);
                    string mediaUrl = Sitecore.Resources.Media.MediaManager.GetMediaUrl(mditm);
                    if (mediaUrl.Contains("/sitecore/shell"))
                    {
                        mediaUrl = mediaUrl.Replace("/sitecore/shell", "");
                    }
                    //To have a preview of images.
                    if (mditm.Extension.ToLower().Contains("jpg") || mditm.Extension.ToLower().Contains("jpeg") || mditm.Extension.ToLower().Contains("png") || mditm.Extension.ToLower().Contains("gif"))
                    {
                        if (lnkScreenShot != null)
                        {
                            lnkScreenShot.Attributes.Add("rel", Sitecore.Resources.Media.MediaManager.GetMediaUrl(mditm));
                            lnkScreenShot.HRef = Sitecore.Resources.Media.MediaManager.GetMediaUrl(mditm);
                            lnkScreenShot.Target = "_balnk";
                        }
                    }
                }



            }
        }
</script>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <script type="text/javascript">
        function MediaItemDeleteConfirmation() {
            return confirm("Are you sure you want to move selected Items to recylce bin?");
        }
        function EmptyRecycleBinConfirmation() {
            return confirm("Are you sure you want to delete all items permanently from recycle bin?");
        }

        function MediaItemPermDeleteConfirmation() {
            return confirm("Are you sure you want to delete selected Items permanently?");
        }

    </script>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>

    <script type="text/javascript">
        $(function () {
            $("#unusedItems [id*=chkHeader]").click(function () {
                if ($("#unusedItems [id*=chkHeader]").is(":checked")) {
                    $("#unusedItems [id*=chkItem]").attr("checked", "checked");
                    $("#unusedItems [id*=chkItem]").prop("checked", true);
                } else {
                    $("#unusedItems [id*=chkItem]").removeAttr("checked");
                }
            });
            $("#unusedItems [id*=chkItem]").click(function () {
                if ($("#unusedItems [id*=chkItem]").length == $("#unusedItems [id*=chkItem]:checked").length) {
                    $("#unusedItems [id*=chkHeader]").attr("checked", "checked");
                    $("#unusedItems [id*=chkHeader]").prop("checked", true);
                } else {
                    $("#unusedItems [id*=chkHeader]").removeAttr("checked");
                }
            });
        });
    </script>
    <script type="text/javascript">
        this.screenshotPreview = function () {
            /* CONFIG */
            xOffset = 10;
            yOffset = 30;

            // these 2 variable determine popup's distance from the cursor
            // you might want to adjust to get the right result

            /* END CONFIG */
            $("a.screenshot").hover(function (e) {
                this.t = this.title;
                this.title = "";
                var c = (this.t != "") ? "<br/>" + this.t : "";
                $("body").append("<p id='screenshot'><img src='" + this.rel + "' alt='url preview' />" + c + "</p>");
                $("#screenshot")
                    .css("top", (e.pageY - xOffset) + "px")
                    .css("left", (e.pageX + yOffset) + "px")
                    .fadeIn("fast");
            },
            function () {
                this.title = this.t;
                $("#screenshot").remove();
            });
            $("a.screenshot").mousemove(function (e) {
                $("#screenshot")
                    .css("top", (e.pageY - xOffset) + "px")
                    .css("left", (e.pageX + yOffset) + "px");
            });
        };


        // starting the script on page load
        $(document).ready(function () {
            screenshotPreview();
        });
    </script>

    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script>
      <script src="https://code.jquery.com/jquery-1.11.3.min.js"></script>
     <script src="http://cdn.datatables.net/1.10.10/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/colreorder/1.3.0/js/dataTables.colReorder.min.js"></script>
    <script src="https://cdn.datatables.net/fixedcolumns/3.2.0/js/dataTables.fixedColumns.min.js"></script>
    

    <link href='https://fonts.googleapis.com/css?family=Roboto:400,900' rel='stylesheet' type='text/css'/>
        <link rel="stylesheet" href="http://cdn.datatables.net/1.10.10/css/jquery.dataTables.min.css" type="text/css" />

    <style>
        #meditmTbl{
            width:100%;
        }
        thead .itmnm {
            max-width: 35%;
        }
        thead .itmpath {
            max-width: 35%;
        }
        thead .itmid {
            max-width: 20%;
        }
    </style>


    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">

    <!-- Optional theme -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap-theme.min.css">

    <!-- Latest compiled and minified JavaScript -->
    <script src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.2/js/bootstrap.min.js"></script>
    <title>Unreferenced Media Items</title>
    <style>
        .jumbotron .h1, .jumbotron h1 {
            font-size: 48px;
        }

        .jumbotron p {
            font-size: 16px;
        }


        .aspNetDisabled {
            -webkit-appearance: button;
            cursor: pointer;
            text-shadow: 0 1px 0 #fff;
            background-image: -webkit-linear-gradient(top,#fff 0,#e0e0e0 100%);
            background-image: -o-linear-gradient(top,#fff 0,#e0e0e0 100%);
            background-image: -webkit-gradient(linear,left top,left bottom,from(#fff),to(#e0e0e0));
            background-image: linear-gradient(to bottom,#fff 0,#e0e0e0 100%);
            filter: progid:DXImageTransform.Microsoft.gradient(startColorstr='#ffffffff', endColorstr='#ffe0e0e0', GradientType=0);
            filter: progid:DXImageTransform.Microsoft.gradient(enabled=false);
            background-repeat: repeat-x;
            border-color: #dbdbdb;
            border-color: #ccc;
                display: inline-block;
    padding: 6px 12px;
    margin-bottom: 0;
    font-size: 14px;
    font-weight: 400;
    line-height: 1.42857143;
    text-align: center;
    white-space: nowrap;
    vertical-align: middle;
    -ms-touch-action: manipulation;
    touch-action: manipulation;    
    -webkit-user-select: none;
    box-shadow: inset 0 1px 0 rgba(255,255,255,.15),0 1px 1px rgba(0,0,0,.075);
    background-image: linear-gradient(to bottom,#fff 0,#e0e0e0 100%);
        text-shadow: 0 1px 0 #fff;
            -webkit-appearance: button;
        color: #333;
    border-color: #adadad;
        }

        input[type=checkbox], input[type=radio] {
            height: 16px;
            width: 16px;
        }
    </style>
    <style>
        img {
            border: none;
            max-width: 400px;
            width:100%;
            height: auto;
        }
        /*  */

        #screenshot {
            position: absolute;
            border: 1px solid #ccc;
            /*background: #333;*/
            padding: 5px;
            display: none;
            color: #fff;
        }

        /*  */
    </style>
</head>
<body>
    <form id="form1" runat="server">       
        <div class="container">
            <div class="jumbotron">
                <h1>Remove Unreferenced Media Items from Sitecore</h1>
                <p>This tool is used to listout and/or remove the unreferenced media items from the CMS.</p>
                <p><b>This tool will list out the media items which are not linked to any item in CMS. It might be possible that the media listed by this tool is used in Code/CSS(Backend Code). Therefore we suggest you to ensure and confirm before deleting any media item.<br /><br />

                <p>
                    Options:<br />                   
                    Database: Select the database from which you want to remove the media<br/>
                    Include media of System Folder: - it will include the media items of system folder. System folder is used by sitecore.<br/>
                    Give appropriate path of the media root folder. If blank, it will take sitecore/media library path.<br />
                    Click on the 'Go' button to list all the unused media items.<br/>
                    Select the items you want to remove by checking the checkbox<br/>                    
                    Once 'Move to Recycle bin' button is clicked all the selected items will be moved to <b>Recycle Bin</b>. You can restore the mistakenly deleted item from Recyle bin.<br/> 
                    <b>If you click on 'Delete button', the selected items will be deleted permanently and can not be recovered.</b>                    
                </p>
            </div>
            <div class="form-group">
                <div class="row">
                    <div class="col-sm-4">
                        <label for="ddDb" title="Please select database">Please select database:</label></div>
                    <div class="col-sm-8">
                        <asp:DropDownList ID="ddDb" runat="server" AutoPostBack="true"></asp:DropDownList>
                    </div>
                </div>

                <div class="row">
                    <div class="col-sm-4">
                        <label for="chkIncludeSystem" title="Do you want to include media of System folder">Do you want to include media of System folder</label>
                    </div>
                    <div class="col-sm-8">
                        <asp:CheckBox ID="chkIncludeSystem" runat="server" />
                    </div>
                </div>
                  <div class="row">
                    <div class="col-sm-4">
                        <label for="chkRemoveMediaFolder" title="Do you want to delete/recycle empty Media Folders?">Do you want to delete/recycle empty Media Folders?</label>
                    </div>
                    <div class="col-sm-8">
                        <asp:CheckBox ID="chkRemoveMediaFolder" runat="server" />
                    </div>
                </div>
                 <div class="row">
                    <div class="col-sm-4">
                        <label for="txtmediarootpath" title="Media Item root path">Media Item root path:</label>
                    </div>
                    <div class="col-sm-8">
                        <asp:TextBox ID="txtmediarootpath" Text="/sitecore/media library" runat="server"></asp:TextBox>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <asp:Button class="btn btn-default" ID="btnGo" runat="server" OnClick="btnGo_Click" Text="GO" />
                <asp:Button class="btn btn-default" ID="btnDelete" runat="server" OnClientClick="if (!MediaItemDeleteConfirmation()) return false;" OnClick="btnDelete_Click" Text="Move to Recycle bin" Enabled="false" />
                <asp:Button class="btn btn-default" ID="btnPermDelete" runat="server" OnClientClick="if (!MediaItemPermDeleteConfirmation()) return false;" OnClick="btnPermDelete_Click" Text="Delete" Enabled="false" />
               
               <%--  <asp:Button class="btn btn-default" ID="btnEmptyRecycleBin" OnClientClick="if (!EmptyRecycleBinConfirmation()) return false;" runat="server" OnClick="btnEmptyRecycleBin_Click" Text="Empty Recycle bin" />--%>
            </div>
              <asp:Label ID="lblMessage" runat="server"></asp:Label>
                <br />
            <asp:Panel ID="pnlmedias" runat="server">
            <div class="form-group">
              
                <asp:Label ID="lblTotalCount" runat="server"></asp:Label>
            </div>
            <asp:ScriptManager ID="MainScriptManager" runat="server" />      
                <div class="form-group" id="unusedItems">
                                     <asp:Repeater ID="rptUnusedItems" runat="server" OnItemDataBound="rptUnusedItems_ItemDataBound">
                        <HeaderTemplate>
                         
                            <div class="table-responsive">          
  <table class="table" width="100%" id="meditmTbl">
      <thead>
          <tr>
              <td> <asp:CheckBox ID="chkHeader" runat="server" ClientIDMode="Static" /></td>
              <td class="itmnm">Item Name</td>
              <td class="itmpath">Path</td>
              <td class="itmid">ID</td>

          </tr>
      </thead>
                        </HeaderTemplate>
                        <ItemTemplate>
                            
                             <tr>
                            <td class="itmnm">   <asp:CheckBox ID="chkItem" runat="server" ClientIDMode="Static" /></td>
                            <td class="itmpath"> <a href="#" class="screenshot" id="lnkScreenShot" runat="server">
                                        <%# ((Sitecore.Data.Items.Item)Container.DataItem).Name%>
                                    </a></td>
                            <td><%# ((Sitecore.Data.Items.Item)Container.DataItem).Paths.Path%></td>
                            <td> <asp:Label ID="lblItemID" runat="server" Text="<%# ((Sitecore.Data.Items.Item)Container.DataItem).ID%>"></asp:Label></td>
                        </tr>
                        </ItemTemplate>
                        <FooterTemplate>
                            </table>
                        </div>
                        </FooterTemplate>
                    </asp:Repeater>
                </div>
                </asp:Panel>
              
        </div>
    </form>

    <script type="text/javascript">
        $(document).ready(function () {
            var table =
        $('#meditmTbl').DataTable({
            "pagingType": "full_numbers",
            "order": [[2, "asc"]],
            "aoColumnDefs": [
    { "bSortable": false, "aTargets": [0] }
            ],
            "colReorder": {
                fixedColumnsLeft: 1,
                fixedColumnsRight: 0
            }
        });
        });
    </script>
	<footer class="footer">
      <div class="container">
        <p class="text-muted">Author Information:<br/>
			Alok KaduDeshmukh<br/>
			Blog url:<a href="http://learnsitecorebasics.wordpress.com" target="_blank">learnsitecorebasics.wordpress.com</a><br/>
			Email:<a href="mailto:alok.kadudeshmukh@yahoo.com" target="_top"> alok.kadudeshmukh@yahoo.com </a><br/>
			
			</p>
      </div>
    </footer>
	
</body>
</html>
