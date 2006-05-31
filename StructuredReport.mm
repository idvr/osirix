//
//  StructuredReport.mm
//  OsiriX
//
//  Created by Lance Pysher on 5/31/06.

/*=========================================================================
  Program:   OsiriX

  Copyright (c) OsiriX Team
  All rights reserved.
  Distributed under GNU - GPL
  
  See http://homepage.mac.com/rossetantoine/osirix/copyright.html for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.
=========================================================================*/

#import "StructuredReport.h"
#import "browserController.h"

#undef verify

#include "osconfig.h"    /* make sure OS specific configuration is included first */
#include "ofstream.h"
#include "dsrdoc.h"
#include "dcuid.h"
#include "dcfilefo.h"


@implementation StructuredReport

- (id)initWithStudy:(id)study{
	if (self = [super init]){
		_doc = new DSRDocument();
	}
	return self;
}

- (void)dealloc{
	delete _doc;
	[super dealloc];
}

- (NSArray *)findings{
	
	if (!_findings)
		_findings = [[NSArray alloc] init];
	return _findings;
}
- (void)setFindings:(NSArray *)findings{
	//NSLog(@"setFindings: %@", [findings description]);
	[_findings release];
	_findings = [findings retain];
}

- (NSArray *)conclusions{
	if (!_conclusions)
		_conclusions = [[NSArray alloc] init];
	return _conclusions;
}
- (void)setConclusions:(NSArray *)conclusions{
	//NSLog(@"setConclusions: %@", [conclusions description]);
	[_conclusions release];
	_conclusions = [conclusions retain];
}

- (NSString *)physician{
	return _physician;
}
- (void)setPhysician:(NSString *)physician{
	[_physician release];
	_physician = [physician retain];
}

- (NSString *)history{
	return _history;
}

- (void)setHistory:(NSString *)history{
	[_history release];
	_history = [history retain];
}

- (BOOL)fileExists{
	if ([_study valueForKey:@"reportURL"])
		return YES;
	return NO;
}

- (void)createReport{
	NSLog(@"Create report");
	

	NSLog(@"study: %@", [_study description]);
	_doc->createNewDocument(DSRTypes::DT_BasicTextSR);
	_doc->setSpecificCharacterSet("ISO_IR 192"); //UTF 8 string encoding
	_doc->createNewSeriesInStudy([[_study valueForKey:@"studyInstanceUID"] UTF8String]);
	//Study Description
	if ([_study valueForKey:@"studyName"])
		_doc->setStudyDescription([[_study valueForKey:@"studyName"] UTF8String]);
	//Series Description
	_doc->setSeriesDescription("OsiriX Structured Report");
	//Patient Name
	if ([_study valueForKey:@"name"] )
		_doc->setPatientsName([[_study valueForKey:@"name"] UTF8String]);
	// Patient DOB
	if ([_study valueForKey:@"dateOfBirth"])
		_doc->setPatientsBirthDate([[[_study valueForKey:@"dateOfBirth"] descriptionWithCalendarFormat:@"%Y%m%d" timeZone:nil locale:nil] UTF8String]);
	//Patient Sex
	if ([_study valueForKey:@"patientSex"])
		_doc->setPatientsSex([[_study valueForKey:@"patientSex"] UTF8String]);
	//Patient ID
	NSString *patientID = [_study valueForKey:@"patientID"];
	if ([patientID UTF8String])
		_doc->setPatientID([patientID UTF8String]);
	//Referring Physician
	if ([_study valueForKey:@"referringPhysician"])
		_doc->setReferringPhysiciansName([[_study valueForKey:@"referringPhysician"] UTF8String]);
	//StudyID	
	if ([_study valueForKey:@"id"]) {
		NSString *studyID = [(NSNumber *)[_study valueForKey:@"id"] stringValue];
		_doc->setStudyID([studyID UTF8String]);
	}
	//Accession Number
	if ([_study valueForKey:@"accessionNumber"])
		_doc->setAccessionNumber([[_study valueForKey:@"accessionNumber"] UTF8String]);
	//Series Number
	_doc->setSeriesNumber("5001");
	
	_doc->getTree().addContentItem(DSRTypes::RT_isRoot, DSRTypes::VT_Container);
	_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("11528-7", "LN", "Radiology Report"));
	if (_physician) {
		_doc->getTree().addContentItem(DSRTypes::RT_hasObsContext, DSRTypes::VT_PName, DSRTypes::AM_belowCurrent);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121008", "DCM", "Person Observer Name"));
		_doc->getTree().getCurrentContentItem().setStringValue([_physician UTF8String]);
	}
	
	if ([_study valueForKey:@"institutionName"]) {
		_doc->getTree().addContentItem(DSRTypes::RT_hasObsContext, DSRTypes::VT_Text);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121009", "DCM", "Person Observer's Organization Name"));
		_doc->getTree().getCurrentContentItem().setStringValue([[_study valueForKey:@"institutionName"] UTF8String]);
	}
	
	if (_history) {
		_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121060", "DCM", "History"));
		_doc->getTree().getCurrentContentItem().setStringValue([_history UTF8String]);
	}
	
	if ([_findings count] > 0) {
	    _doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Container);
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121070", "DCM", "Findings"));
		NSEnumerator *enumerator = [_findings objectEnumerator];
		NSDictionary *dict;
		BOOL first = YES;
		NSLog(@"findings: %@", [_findings description]);
		
		while (dict = [enumerator nextObject]) {
			NSString *finding = [dict objectForKey:@"finding"];
			NSLog(@"finding: %@", finding);
			if (finding){
				if (first) {
					// go down one level if first Finding
					_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text, DSRTypes::AM_belowCurrent);
					first = NO;
				}
				else
					_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
				_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121071", "DCM", "Finding"));
				_doc->getTree().getCurrentContentItem().setStringValue([finding UTF8String]);
			}
		}
		
	}
	
		//go back up in tree
		_doc->getTree().goUp();
		
	if ([_conclusions count] > 0) {
		_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Container);
		//SH.07 is probably wrong. I'm not sure how to get the right values here.
		_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121072", "DCM", "Impressions"));
		NSEnumerator *enumerator = [_conclusions objectEnumerator];
		NSDictionary *dict;
		BOOL first = YES;
		
		while (dict = [enumerator nextObject]) {
			if (first) {
				// go down one level if first Finding
				_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text, DSRTypes::AM_belowCurrent);
				first = NO;
			}
			else
				_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Text);
			NSString *conclusion = [dict objectForKey:@"conclusion"];			
			_doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121073", "DCM", "Impression"));
			_doc->getTree().getCurrentContentItem().setStringValue([conclusion UTF8String]);
		}
		
	}
	
	//go back up in tree
	_doc->getTree().goUp();
	
	/***** Exmaple of code to add a reference image **************
	_doc->getTree().addContentItem(DSRTypes::RT_contains, DSRTypes::VT_Image);
    _doc->getTree().getCurrentContentItem().setConceptName(DSRCodedEntryValue("121180", DCM, "Key Images"));
    _doc->getTree().getCurrentContentItem().setImageReference(DSRImageReferenceValue(SOPClassUID, SOPInstanceUID));
    _doc->getCurrentRequestedProcedureEvidence().addItem(const OFString &studyUID, const OFString &seriesUID, const OFString &sopClassUID, const OFString &instanceUID);
	*/

	// write out SR
	NSString *dbPath = [[[BrowserController currentBrowser] documentsDirectory] stringByAppendingPathComponent:@"REPORTS"];
	DcmFileFormat fileformat;
	

	OFCondition status = _doc->write(*fileformat.getDataset());
	NSString *path = [[dbPath stringByAppendingPathComponent:[_study valueForKey:@"studyInstanceUID"]] stringByAppendingPathExtension:@"dcm"];
	status = fileformat.saveFile([path UTF8String], EXS_LittleEndianExplicit);
	[_study setValue: path ForKey:@"reportURL"];

}

- (void)writeHTML{
	size_t renderFlags = DSRTypes::HF_renderDcmtkFootnote;
	NSString *tempPath = @"/tmp";
	NSString *path = [[tempPath stringByAppendingPathComponent:[_study valueForKey:@"studyInstanceUID"]] stringByAppendingPathExtension:@"html"];		
				ofstream stream([path UTF8String]);
	_doc->renderHTML(stream, renderFlags, NULL);
}
- (void)writeXML{
}
- (void)readXML{
}
- (NSString *)xmlPath{
	return nil;
}
- (NSString *)htmlPath{
 return nil;
}
- (NSString *)srPath{
	return nil;
}


	

@end
