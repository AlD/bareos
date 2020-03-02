<?php

/**
*
* bareos-webui - Bareos Web-Frontend
*
* @link      https://github.com/bareos/bareos for the canonical source repository
* @copyright Copyright (c) 2013-2019 Bareos GmbH & Co. KG (http://www.bareos.org/)
* @license   GNU Affero General Public License (http://www.gnu.org/licenses/)
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero General Public License for more details.
*
* You should have received a copy of the GNU Affero General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*/

namespace Restore\Form;

use Zend\Form\Form;
use Zend\Form\Element;

class RestoreForm extends Form
{

   protected $restore_params;
   protected $clients;
   protected $filesets;
   protected $restorejobs;
   protected $jobids;
   protected $backups;

   public function __construct($restore_params=null, $clients=null, $filesets=null, $restorejobs=null, $jobids=null, $backups=null)
   {

      parent::__construct('restore');

      $this->restore_params = $restore_params;
      $this->clients = $clients;
      $this->filesets = $filesets;
      $this->restorejobs = $restorejobs;
      $this->jobids = $jobids;
      $this->backups = $backups;

      // Backup jobs
      if(isset($restore_params['jobid'])) {
         $this->add(array(
            'name' => 'backups',
            'type' => 'select',
            'options' => array(
               'label' => _('Backup jobs'),
               'empty_option' => _('Please choose a backup'),
               'value_options' => $this->getBackupList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'jobid',
               'value' => $restore_params['jobid']
            )
         ));
      }
      else {
         $this->add(array(
            'name' => 'backups',
            'type' => 'select',
            'options' => array(
               'label' => _('Backups'),
               'empty_option' => _('Please choose a backup'),
               'value_options' => $this->getBackupList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'jobid',
               'disabled' => true
            )
         ));
      }

      // Client
      if(isset($restore_params['client'])) {
         if($restore_params['type'] == "client") {
            $this->add(array(
               'name' => 'client',
               'type' => 'select',
               'options' => array(
                  'label' => _('Client'),
                  'empty_option' => _('Please choose a client'),
                  'value_options' => $this->getClientList()
               ),
               'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'data-live-search' => 'true',
                  'id' => 'client',
                  'value' => $restore_params['client']
               )
            ));
         }
         else {
            $this->add(array(
               'name' => 'client',
               'type' => 'select',
               'options' => array(
                  'label' => _('Client'),
                  'empty_option' => _('Please choose a client'),
                  'value_options' => $this->getClientList()
               ),
               'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'data-live-search' => 'true',
                  'id' => 'client',
                  'value' => $restore_params['client']
               )
            ));
         }
      }
      else {
         $this->add(array(
            'name' => 'client',
            'type' => 'select',
            'options' => array(
               'label' => _('Client'),
               'empty_option' => _('Please choose a client'),
               'value_options' => $this->getClientList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'client',
               'value' => ''
            )
         ));
      }

      // Restore client
      if(isset($restore_params['restoreclient'])) {
         $this->add(array(
            'name' => 'restoreclient',
            'type' => 'select',
            'options' => array(
               'label' => _('Restore to client'),
               'empty_option' => _('Please choose a client'),
               'value_options' => $this->getClientList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'restoreclient',
               'value' => $restore_params['restoreclient']
            )
         ));
      }
      elseif(!isset($restore_params['restoreclient']) && isset($restore_params['client']) ) {
         $this->add(array(
            'name' => 'restoreclient',
            'type' => 'select',
            'options' => array(
               'label' => _('Restore to client'),
               'empty_option' => _('Please choose a client'),
               'value_options' => $this->getClientList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'restoreclient',
               'value' => $restore_params['client']
            )
         ));
      }
      else {
         $this->add(array(
            'name' => 'restoreclient',
            'type' => 'select',
            'options' => array(
               'label' => _('Restore to (another) client'),
               'empty_option' => _('Please choose a client'),
               'value_options' => $this->getClientList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'restoreclient',
               'disabled' => true
            )
         ));
      }

      // Fileset
      if(isset($restore_params['fileset'])) {
         $this->add(array(
            'name' => 'fileset',
            'type' => 'select',
            'options' => array(
               'label' => _('Fileset'),
               'empty_option' => _('Please choose a fileset'),
               'value_options' => $this->getFilesetList()
            ),
            'attributes' => array(
               'id' => 'fileset',
               'value' => $restore_params['fileset']
            )
         ));
      }
      else {
         $this->add(array(
            'name' => 'fileset',
            'type' => 'select',
            'options' => array(
               'label' => _('Fileset'),
               'empty_option' => _('Please choose a fileset'),
               'value_options' => $this->getFilesetList()
            ),
            'attributes' => array(
               'id' => 'fileset'
            )
         ));
      }

      // Restore Job
      if(isset($restore_params['restorejob'])) {
         $this->add(array(
            'name' => 'restorejob',
            'type' => 'select',
            'options' => array(
               'label' => _('Restore job'),
               //'empty_option' => _('Please choose a restore job'),
               'value_options' => $this->getRestoreJobList()
            ),
            'attributes' => array(
               'class' => 'form-control selectpicker show-tick',
               'data-live-search' => 'true',
               'id' => 'restorejob',
               'value' => $restore_params['restorejob']
            )
         ));
      }
      else {
         if(!empty($this->restore_params['client']) && count($this->getRestoreJobList()) > 0) {
            $this->add(array(
               'name' => 'restorejob',
               'type' => 'select',
               'options' => array(
                  'label' => _('Restore job'),
                  'empty_option' => _('Please choose a restore job'),
                  'value_options' => $this->getRestoreJobList()
               ),
               'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'data-live-search' => 'true',
                  'id' => 'restorejob',
                  'value' => @array_pop($this->getRestoreJobList())
               )
            ));
         }
         else {
            $this->add(array(
               'name' => 'restorejob',
               'type' => 'select',
               'options' => array(
                  'label' => _('Restore job'),
                  'empty_option' => _('Please choose a restore job'),
                  'value_options' => $this->getRestoreJobList()
               ),
               'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'data-live-search' => 'true',
                  'id' => 'restorejob',
                  'disabled' => true
               )
            ));
         }
      }

      // Merge filesets
      if(isset($this->restore_params['client']) && isset($restore_params['mergefilesets'])) {
         $this->add(array(
            'name' => 'mergefilesets',
            'type' => 'select',
            'options' => array(
               'label' => _('Merge all client filesets'),
               'value_options' => array(
                     '0' => _('Yes'),
                     '1' => _('No')
                  )
               ),
            'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'id' => 'mergefilesets',
                  'value' => $restore_params['mergefilesets']
               )
            )
         );
      }
      else {
         $this->add(array(
            'name' => 'mergefilesets',
            'type' => 'select',
            'options' => array(
               'label' => _('Merge all client filesets'),
               'value_options' => array(
                     '0' => _('Yes'),
                     '1' => _('No')
                  )
               ),
            'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'id' => 'mergefilesets',
                  'value' => '0',
                  'disabled' => true
               )
            )
         );
      }

      // Merge jobs
      if(isset($this->restore_params['client']) && isset($restore_params['mergejobs'])) {
         $this->add(array(
            'name' => 'mergejobs',
            'type' => 'select',
            'options' => array(
               'label' => _('Merge all related jobs to last full backup of selected backup job'),
               'value_options' => array(
                     '0' => _('Yes'),
                     '1' => _('No')
                  )
               ),
            'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'id' => 'mergejobs',
                  'value' => $restore_params['mergejobs']
               )
            )
         );
      }
      else {
         $this->add(array(
            'name' => 'mergejobs',
            'type' => 'select',
            'options' => array(
               'label' => _('Merge jobs'),
               'value_options' => array(
                     '0' => _('Yes'),
                     '1' => _('No')
                  )
               ),
            'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'id' => 'mergejobs',
                  'value' => '0',
                  'disabled' => true
               )
            )
         );
      }

      // Replace
      if(isset($restore_params['client'])) {
        $this->add(array(
           'name' => 'replace',
           'type' => 'select',
           'options' => array(
              'label' => _('Replace files on client'),
              'value_options' => array(
                    'always' => _('always'),
                    'never' => _('never'),
                    'ifolder' => _('if file being restored is older than existing file'),
                    'ifnewer' => _('if file being restored is newer than existing file')
                 )
              ),
           'attributes' => array(
                 'class' => 'form-control selectpicker show-tick',
                 'id' => 'replace',
                 'value' => 'never'
              )
           )
        );
      }
      else {
        $this->add(array(
            'name' => 'replace',
            'type' => 'select',
            'options' => array(
               'label' => _('Replace files on client'),
               'value_options' => array(
                     'always' => _('always'),
                     'never' => _('never'),
                     'ifolder' => _('if file being restored is older than existing file'),
                     'ifnewer' => _('if file being restored is newer than existing file')
                  )
               ),
            'attributes' => array(
                  'class' => 'form-control selectpicker show-tick',
                  'id' => 'replace',
                  'value' => 'never',
                  'disabled' => true
               )
            )
         );
      }

      // Where
      if(isset($this->restore_params['client'])) {
        $this->add(array(
           'name' => 'where',
           'type' => 'text',
           'options' => array(
              'label' => _('Restore location on client')
              ),
           'attributes' => array(
              'class' => 'form-control selectpicker show-tick',
              'value' => '/tmp/bareos-restores/',
              'id' => 'where',
              'size' => '30',
              'placeholder' => _('e.g. / or /tmp/bareos-restores/')
              )
           )
        );
      }
      else {
        $this->add(array(
           'name' => 'where',
           'type' => 'text',
           'options' => array(
              'label' => _('Restore location on client')
              ),
           'attributes' => array(
              'class' => 'form-control selectpicker show-tick',
              'value' => '/tmp/bareos-restores/',
              'id' => 'where',
              'size' => '30',
              'placeholder' => _('e.g. / or /tmp/bareos-restores/'),
              'disabled' => true
              )
           )
        );
      }

      // JobIds hidden
      $this->add(array(
         'name' => 'jobids_hidden',
         'type' => 'Zend\Form\Element\Hidden',
         'attributes' => array(
            'value' => $this->getJobIds(),
            'id' => 'jobids_hidden'
            )
         )
      );

      // JobIds display (for debugging)
      $this->add(array(
         'name' => 'jobids_display',
         'type' => 'text',
         'options' => array(
            'label' => _('Related jobs for a most recent full restore')
            ),
         'attributes' => array(
            'value' => $this->getJobIds(),
            'id' => 'jobids_display',
            'readonly' => true
            )
         )
      );

      // filebrowser checked files
      $this->add(array(
         'name' => 'checked_files',
         'type' => 'Zend\Form\Element\Hidden',
         'attributes' => array(
            'value' => '',
            'id' => 'checked_files'
            )
         )
      );

      // filebrowser checked directories
      $this->add(array(
         'name' => 'checked_directories',
         'type' => 'Zend\Form\Element\Hidden',
         'attributes' => array(
            'value' => '',
            'id' => 'checked_directories'
            )
         )
      );

      // Submit button
      if(isset($this->restore_params['client'])) {
        $this->add(array(
          'name' => 'form-submit',
          'type' => 'button',
          'options' => array(
            'label' => _('Restore')
          ),
          'attributes' => array(
            //'value' => _('Restore'),
            'id' => 'btn-form-submit',
            'class' => 'btn btn-primary'
          )
        ));
      }
      else {
        $this->add(array(
           'name' => 'form-submit',
           'type' => 'button',
           'options' => array(
             'label' => _('Restore')
           ),
           'attributes' => array(
              //'value' => _('Restore'),
              'id' => 'btn-form-submit',
              'class' => 'btn btn-primary',
              'disabled' => true
           )
        ));
      }

   }

   /**
    *
    */
   private function getJobList()
   {
      $selectData = array();
      if(!empty($this->jobs)) {
         foreach($this->jobs as $job) {
            $selectData[$job['jobid']] = $job['jobid'] . " - " . $job['name'];
         }
      }
      return $selectData;
   }

   /**
    *
    */
   private function getBackupList()
   {
      $selectData = array();
      if(!empty($this->backups)) {

         foreach($this->backups as $backup) {
            switch($backup['level']) {
               case 'I':
                  $level = "Incremental";
                  break;
               case 'D':
                  $level = "Differential";
                  break;
               case 'F':
                  $level = "Full";
                  break;
            }
            $selectData[$backup['jobid']] = "(" . $backup['jobid']  . ") " . $backup['starttime'] . " - " . $backup['name'] . " - " . $level;
         }
      }
      return $selectData;
   }

   /**
    *
    */
   private function getJobIds()
   {
      return $this->jobids;
   }

   /**
    *
    */
   private function getClientList()
   {
      $selectData = array();
      if(!empty($this->clients)) {
         foreach($this->clients as $client) {
            $selectData[$client['name']] = $client['name'];
         }
      }
      ksort($selectData);
      return $selectData;
   }

   /**
    *
    */
   private function getFilesetList()
   {
      $selectData = array();
      if(!empty($this->filesets)) {
         foreach($this->filesets as $fileset) {
            $selectData[$fileset['name']] = $fileset['name'];
         }
      }
      return $selectData;
   }

   /**
    *
    */
   private function getRestoreJobList()
   {
      $selectData = array();
      if(!empty($this->restorejobs)) {
         foreach($this->restorejobs as $restorejob) {
            $selectData[$restorejob['name']] = $restorejob['name'];
         }
      }
      return $selectData;
   }

}
