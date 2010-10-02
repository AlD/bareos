/*
   Bacula® - The Network Backup Solution

   Copyright (C) 2007-2009 Free Software Foundation Europe e.V.

   The main author of Bacula is Kern Sibbald, with contributions from
   many others, a complete list can be found in the file AUTHORS.
   This program is Free Software; you can redistribute it and/or
   modify it under the terms of version three of the GNU Affero General Public
   License as published by the Free Software Foundation and included
   in the file LICENSE.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU Affero General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
   02110-1301, USA.

   Bacula® is a registered trademark of Kern Sibbald.
   The licensor of Bacula is the Free Software Foundation Europe
   (FSFE), Fiduciary Program, Sumatrastrasse 25, 8006 Zürich,
   Switzerland, email:ftf@fsfeurope.org.
*/
 
/*
 *
 *  bRestore Class  (Eric's brestore)
 *
 *   Kern Sibbald, January MMVII
 *
 */ 

#include "bat.h"
#include "restore.h"
#include "util/fmtwidgetitem.h"

bRestore::bRestore()
{
   m_name = tr("bRestore");
   m_client = "";
   setupUi(this);
   pgInitialize();
   QTreeWidgetItem* thisitem = mainWin->getFromHash(this);
   thisitem->setIcon(0, QIcon(QString::fromUtf8(":images/browse.png")));
   m_populated = false;
   m_current = NULL;
   RestoreList->setAcceptDrops(true);
}

void bRestore::setClient()
{
   Pmsg0(000, "Repopulating client table\n");
   // Select the same client, don't touch
   if (m_client == ClientList->currentText()) {
      return;
   }
   m_client = ClientList->currentText();
   FileList->clearContents();
   FileRevisions->clearContents();
   JobList->clear();
   JobList->setEnabled(true);
   LocationEntry->clear();
   m_path = "";
   m_pathid = 0;

   if (ClientList->currentIndex() < 1) {
      JobList->setEnabled(false);
      return;
   }

   JobList->addItem("Job list for " + m_client);

   QString jobQuery =
      "SELECT Job.Jobid AS JobId, Job.StartTime AS StartTime,"
      " Job.Level AS Level,"
      " Job.Name AS Name"
      " FROM Job JOIN Client USING (ClientId)"
      " WHERE"
      " Job.JobStatus IN ('T','W') AND Job.Type='B' AND"
      " Client.Name='" + m_client + "' ORDER BY StartTime DESC" ;

   QString job;
   QStringList results;
   if (m_console->sql_cmd(jobQuery, results)) {
      QStringList fieldlist;

      /* Iterate through the record returned from the query */
      foreach (QString resultline, results) {
         fieldlist = resultline.split("\t");
         job = fieldlist[1] + " " + fieldlist[3] + "(" + fieldlist[2] + ") " + fieldlist[0];
         JobList->addItem(job, QVariant(fieldlist[0]));
      }
   }
}


void bRestore::setJob()
{
   if (JobList->currentIndex() < 1) {
      FileList->clearContents();
      FileList->setRowCount(0);
      FileRevisions->clearContents();
      FileRevisions->setRowCount(0);
      return ;
   }
   QStringList results;
   QVariant tmp = JobList->itemData(JobList->currentIndex(), Qt::UserRole);

   m_jobids = tmp.toString();
   QString cmd = ".bvfs_get_jobids jobid=" + m_jobids;
   if (MergeChk->checkState() == Qt::Checked) {
      cmd.append(" all");
   }

   m_console->dir_cmd(cmd, results);

   if (results.size() < 1) {
      FileList->clearContents();
      FileList->setRowCount(0);
      FileRevisions->clearContents();
      FileRevisions->setRowCount(0);
      return;
   }

   m_jobids = results.at(0);
   cmd = ".bvfs_update jobid=" + m_jobids;
   m_console->dir_cmd(cmd, results);

   Pmsg1(0, "jobids=%s\n", m_jobids.toLocal8Bit().constData());

   displayFiles(m_pathid, QString(""));
   Pmsg0(000, "update done\n");
}

extern int decode_stat(char *buf, struct stat *statp, int32_t *LinkFI);

void bRestore::displayFiles(int64_t pathid, QString path)
{
   QString arg;
   QStringList results;
   QStringList fieldlist;
   struct stat statp;
   int32_t LinkFI;
   int nb;
   int row=0;
   Freeze frz_lst(*FileList); /* disable updating*/
   Freeze frz_rev(*FileRevisions); /* disable updating*/
   FileList->clearContents();
   FileRevisions->clearContents();
   FileRevisions->setRowCount(0);

   if (pathid > 0) {
      arg = " pathid=" + QString().setNum(pathid);

      if (path == "..") {
         if (m_path == "/") {
            m_path = "";
         } else {
            m_path.remove(QRegExp("[^/]+/$"));
         }

      } else if (path == "/" && m_path == "") {
         m_path += path;

      } else if (path != "/" && path != ".") {
         m_path += path;
      }
   } else {
      m_path = path;
      arg = " path=\"" + m_path + "\"";
   }
   LocationEntry->setText(m_path);

   QString q = ".bvfs_lsdir jobid=" + m_jobids + arg;
   if (m_console->dir_cmd(q, results)) {
      nb = results.size();
      FileList->setRowCount(nb);
      foreach (QString resultline, results) {
         int col=0;
         //PathId, FilenameId, fileid, jobid, lstat, path
         fieldlist = resultline.split("\t");
         TableItemFormatter item(*FileList, row++);
         item.setFileType(col++, QString("folder")); // folder or file
         item.setTextFld(col++, fieldlist.at(5)); // path
         decode_stat(fieldlist.at(4).toLocal8Bit().data(), 
                     &statp, &LinkFI);
         item.setDateFld(col++, statp.st_mtime); // date
         item.widget(1)->setData(Qt::UserRole, fieldlist.join("\t")); // keep info
      }
   }

   results.clear();
   q = ".bvfs_lsfiles jobid=" + m_jobids + arg;
   if (m_console->dir_cmd(q, results)) {
      FileList->setRowCount(results.size() + nb);
      foreach (QString resultline, results) {
         int col=1;            // skip icon
         //PathId, FilenameId, fileid, jobid, lstat, name
         fieldlist = resultline.split("\t");
         TableItemFormatter item(*FileList, row++);
         item.setTextFld(col++, fieldlist.at(5)); // name
         decode_stat(fieldlist.at(4).toLocal8Bit().data(), 
                     &statp, &LinkFI);
         item.setBytesFld(col++, QString().setNum(statp.st_size));
         item.setDateFld(col++, statp.st_mtime);
         item.widget(1)->setData(Qt::UserRole, fieldlist.join("\t")); // keep info
      }
   }
   FileList->verticalHeader()->hide();
   FileList->resizeColumnsToContents();
   FileList->resizeRowsToContents();
   FileList->setEditTriggers(QAbstractItemView::NoEditTriggers);
}

void bRestore::PgSeltreeWidgetClicked()
{
   if(!m_populated) {
      setupPage();
   }
   if (!isOnceDocked()) {
      dockPage();
   }
}

void bRestore::displayFileVersion(QString pathid, QString fnid, 
                                  QString client, QString filename)
{
   int row=0;
   struct stat statp;
   int32_t LinkFI;
   Freeze frz_rev(*FileRevisions); /* disable updating*/
   FileRevisions->clearContents();
   
   QString q = ".bvfs_versions jobid=" + m_jobids +
      " pathid=" + pathid + 
      " fnid=" + fnid + 
      " client=" + client;

   if (VersionsChk->checkState() == Qt::Checked) {
      q.append(" versions");
   }

   QStringList results;
   QStringList fieldlist;
   QString tmp;
   if (m_console->dir_cmd(q, results)) {
      FileRevisions->setRowCount(results.size());
      foreach (QString resultline, results) {
         int col=0;
         // 0        1          2        3      4    5      6        7
         //PathId, FilenameId, fileid, jobid, lstat, Md5, VolName, Inchanger
         fieldlist = resultline.split("\t");
         TableItemFormatter item(*FileRevisions, row++);
         item.setInChanger(col++, fieldlist.at(7));    // inchanger
         item.setTextFld(col++, fieldlist.at(6)); // Volume
         item.setNumericFld(col++, fieldlist.at(3)); // JobId
         decode_stat(fieldlist.at(4).toLocal8Bit().data(), 
                     &statp, &LinkFI);
         item.setBytesFld(col++, QString().setNum(statp.st_size)); // size
         item.setDateFld(col++, statp.st_mtime); // date
         item.setTextFld(col++, fieldlist.at(5)); // chksum

         // Adjust the fieldlist for drag&drop
         fieldlist.removeLast(); // inchanger
         fieldlist.removeLast(); // volname
         fieldlist.removeLast(); // md5
         fieldlist << m_path + filename;
         item.widget(1)->setData(Qt::UserRole, fieldlist.join("\t")); // keep info
      }
   }
   FileRevisions->verticalHeader()->hide();
   FileRevisions->resizeColumnsToContents();
   FileRevisions->resizeRowsToContents();
   FileRevisions->setEditTriggers(QAbstractItemView::NoEditTriggers);
}

void bRestore::showInfoForFile(QTableWidgetItem *widget)
{
   m_current = widget;
   QTableWidgetItem *first = FileList->item(widget->row(), 1);
   QStringList lst = first->data(Qt::UserRole).toString().split("\t");
   if (lst.at(1) == "0") {      // no filenameid, should be a path
      displayFiles(lst.at(0).toLongLong(), lst.at(5));
   } else {
      displayFileVersion(lst.at(0), lst.at(1), m_client, lst.at(5));
   }
}

void bRestore::applyLocation()
{
   displayFiles(0, LocationEntry->text());
}

void bRestore::clearVersions(QTableWidgetItem *item)
{
   if (item != m_current) {
      FileRevisions->clearContents();
      FileRevisions->setRowCount(0);
   }
   m_current = item ;
}

void bRestore::setupPage()
{
   ClientList->addItem("Client list");
   ClientList->addItems(m_console->client_list);
   connect(ClientList, SIGNAL(currentIndexChanged(int)), this, SLOT(setClient()));
   connect(JobList, SIGNAL(currentIndexChanged(int)), this, SLOT(setJob()));
   connect(FileList, SIGNAL(itemClicked(QTableWidgetItem*)), 
           this, SLOT(clearVersions(QTableWidgetItem *)));
   connect(FileList, SIGNAL(itemDoubleClicked(QTableWidgetItem*)), 
           this, SLOT(showInfoForFile(QTableWidgetItem *)));
   connect(LocationBp, SIGNAL(pressed()), this, SLOT(applyLocation()));
   connect(MergeChk, SIGNAL(clicked()), this, SLOT(setJob()));

   m_populated = true;
}

bRestore::~bRestore()
{
}

void bRestoreTable::mousePressEvent(QMouseEvent *event)
{
   QTableWidget::mousePressEvent(event);

   if (event->button() == Qt::LeftButton) {
      dragStartPosition = event->pos();
   }
}

// This event permits to send set custom data on drag&drop
// Don't forget to call original class if we are not interested
void bRestoreTable::mouseMoveEvent(QMouseEvent *event)
{
   int lastrow=-1;

   // Look just for drag&drop
   if (!(event->buttons() & Qt::LeftButton)) {
      QTableWidget::mouseMoveEvent(event);
      return;
   }
   if ((event->pos() - dragStartPosition).manhattanLength()
       < QApplication::startDragDistance())
   {
      QTableWidget::mouseMoveEvent(event);
      return;
   }

   QList<QTableWidgetItem *> lst = selectedItems();
   qDebug() << this << " selectedItems: " << lst;
   if (lst.isEmpty()) {
      return;
   }

   QDrag *drag = new QDrag(this);
   QMimeData *mimeData = new QMimeData;
   for (int i=0; i < lst.size(); i++) {
      if (lastrow != lst[i]->row()) {
         lastrow = lst[i]->row();
         QTableWidgetItem *it = item(lastrow, 1);
         mimeData->setText(it->data(Qt::UserRole).toString());
         break;                  // at this time, we do it one by one
      }
   }
   drag->setMimeData(mimeData);
   drag->exec();
}

// This event is called when the drag item enters in the destination area
void bRestoreTable::dragEnterEvent(QDragEnterEvent *event)
{
   if (event->source() == this) {
      event->ignore();
      return;
   }
   if (event->mimeData()->hasText()) {
      event->acceptProposedAction();
   } else {
      event->ignore();
   }
}

// It should not be essential to redefine this event, but it
// doesn't work if not defined
void bRestoreTable::dragMoveEvent(QDragMoveEvent *event)
{
   if (event->mimeData()->hasText()) {
      event->acceptProposedAction();
   } else {
      event->ignore();
   }
}

void bRestoreTable::dropEvent(QDropEvent *event)
{
   int col=1;
   struct stat statp;
   int32_t LinkFI;
   if (event->mimeData()->hasText()) {
      TableItemFormatter item(*this, rowCount());
      setRowCount(rowCount() + 1);
      QStringList fields = event->mimeData()->text().split("\t");
      if (fields.size() != 6) {
         event->ignore();
         return;
      }
      if (fields.at(1) == "0") {
         item.setFileType(0, "folder");
      }
      item.setTextFld(col++, fields.at(5)); // filename
      decode_stat(fields.at(4).toLocal8Bit().data(), 
                  &statp, &LinkFI);
      item.setBytesFld(col++, QString().setNum(statp.st_size)); // size
      item.setDateFld(col++, statp.st_mtime); // date
      item.setNumericFld(col++, fields.at(3)); // jobid
      item.setNumericFld(col++, fields.at(2)); // fileid
      item.widget(1)->setData(Qt::UserRole, event->mimeData()->text());
      event->acceptProposedAction();
   } else {
      event->ignore();
   }
}

