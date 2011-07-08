<?php
/* 
+-------------------------------------------------------------------------+
| Copyright (C) 2004 Juan Luis Franc�s Jim�nez							  |
| Copyright 2010-2011, Davide Franco			                          |
|                                                                         |
| This program is free software; you can redistribute it and/or           |
| modify it under the terms of the GNU General Public License             |
| as published by the Free Software Foundation; either version 2          |
| of the License, or (at your option) any later version.                  |
|                                                                         |
| This program is distributed in the hope that it will be useful,         |
| but WITHOUT ANY WARRANTY; without even the implied warranty of          |
| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           |
| GNU General Public License for more details.                            |
+-------------------------------------------------------------------------+ 
*/
session_start();
include_once( 'config.inc.php' );

$dbSql 				= new Bweb();
$days_stored_bytes 	= array();

// Stored files number 
$dbSql->tpl->assign('stored_files', $dbSql->GetStoredFiles( ALL ) );
  
// Database size
$dbSql->tpl->assign('database_size', $dbSql->GetDbSize());

// Overall stored bytes
$stored_bytes = CUtils::Get_Human_Size( $dbSql->getStoredBytes( FIRST_DAY, NOW ) );
$dbSql->tpl->assign('stored_bytes', $stored_bytes);

// Total stored bytes since last 24 hours
$bytes_last = CUtils::Get_Human_Size( $dbSql->getStoredBytes( LAST_DAY, NOW ) );
$dbSql->tpl->assign('bytes_last', $bytes_last );

// Total stored files since last 24 hours
$files_last = $dbSql->GetStoredFiles( LAST_DAY );
$dbSql->tpl->assign('files_last', $files_last );


// Number of clients
$nb_clients = $dbSql->Get_Nb_Clients();
$dbSql->tpl->assign('clientes_totales',$nb_clients["nb_client"] );

// Backup Job list for report.tpl and last_run_report.tpl
$dbSql->tpl->assign( 'jobs_list', $dbSql->Get_BackupJob_Names() );

// Last 24 hours completed jobs number
$dbSql->tpl->assign( 'completed_jobs', $dbSql->CountJobs( LAST_DAY, 'completed' ) );

// Last 24 hours failed jobs number
$dbSql->tpl->assign( 'failed_jobs', $dbSql->CountJobs( LAST_DAY, 'failed' ) );

// Last 24 hours waiting jobs number
$dbSql->tpl->assign( 'waiting_jobs', $dbSql->CountJobs( LAST_DAY, 'waiting' ) );

// Last 24 hours Job Levels
$dbSql->tpl->assign( 'incr_jobs', $dbSql->CountJobsbyLevel( LAST_DAY, 'I') );
$dbSql->tpl->assign( 'diff_jobs', $dbSql->CountJobsbyLevel( LAST_DAY, 'D') );
$dbSql->tpl->assign( 'full_jobs', $dbSql->CountJobsbyLevel( LAST_DAY, 'F') );

// Last 24 hours Job status graph
$data   = array();  
$status = array( 'completed', 'terminated_errors', 'failed', 'waiting', 'created', 'running', 'error' );

foreach( $status as $job_status ) {
	array_push( $data, $dbSql->GetJobsStatistics( $job_status ) );
}

$graph = new CGraph( "graph.png" );
$graph->SetData( $data, 'pie', 'text-data-single' );
$graph->SetGraphSize( 400, 230 );

$graph->Render();
$dbSql->tpl->assign('graph_jobs', $graph->Get_Image_file() );
unset($graph);

// Pool and volumes graph
$data = array();
$graph = new CGraph( "graph1.png" );

$pools = $dbSql->Get_Pools_List();
while( $pool = $pools->fetchRow( ) ) {
	array_push( $data, $dbSql->CountVolumesByPool( $pool['poolid']) );
}

$graph->SetData( $data, 'pie', 'text-data-single' );
$graph->SetGraphSize( 400, 230 );

$graph->Render();
$dbSql->tpl->assign('graph_pools', $graph->Get_Image_file() );

// Last 7 days stored Bytes graph
$days	= array();

for( $c = 6 ; $c >= 0 ; $c-- ) {
	$today  = NOW - ($c * DAY);
	$days[] = CTimeUtils::get_Day_Intervals($today);
}

foreach( $days as $day ) {
	$stored_bytes 		 = $dbSql->getStoredBytes( $day['start'], $day['end']);
	$stored_bytes 		 = CUtils::Get_Human_Size( $stored_bytes, 1, 'GB', false );
	$days_stored_bytes[] = array( date("m-d", $day['start']), $stored_bytes );  
}

$graph = new CGraph( "graph2.png" );
$graph->SetData( $days_stored_bytes, 'bars', 'text-data' );
$graph->SetGraphSize( 400, 230 );
$graph->SetYTitle( "GB" );

$graph->Render();
$dbSql->tpl->assign('graph_stored_bytes', $graph->Get_Image_file() );


// Last 15 used volumes
$vol_list = array();

$query  = "SELECT DISTINCT Media.Volumename, Media.Lastwritten, Media.VolStatus, Job.JobId FROM Job ";
$query .= "LEFT JOIN JobMedia ON Job.JobId = JobMedia.JobId ";
$query .= "LEFT JOIN Media ON JobMedia.MediaId = Media.MediaId ";
$query .= "ORDER BY Job.JobId DESC ";
$query .= "LIMIT 10 ";

$result = $dbSql->db_link->query( $query );

if ( PEAR::isError( $result ) )
	$this->TriggerDBError( 'Unable to get last used volumes from catalog' . $result );
else {
	while ( $vol = $result->fetchRow() ) 
		array_push( $vol_list, $vol );
}
$dbSql->tpl->assign( 'volume_list', $vol_list );	

// Render template
$dbSql->tpl->display('index.tpl');
?>
